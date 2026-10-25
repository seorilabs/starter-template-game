import Foundation
import AuthenticationServices
import Photos
import StoreKit
import UIKit

@objcMembers
public final class GodotStoreKit2Proxy: NSObject,
@unchecked Sendable
{
	private var accountAuthorization: SeoriAppleAccountAuthorization?
	private var updates: Task<Void, Never>? = nil
	private var unfinished: Task<Void, Never>? = nil
	private var transactionCallback: (TransactionData) -> ()

	public init(transactionCallback: @Sendable @escaping (TransactionData) -> ()) {
		self.transactionCallback = transactionCallback
		super.init()
		updates = newTransactionListenerTask(transactions: Transaction.updates)
		unfinished = newTransactionListenerTask(transactions: Transaction.unfinished)
	}

	public func requestAccountToken(nonce: String, clientId: String, completion: @escaping @Sendable (String, String) -> Void) {
		Task { @MainActor [weak self] in
			guard let self = self, !nonce.isEmpty, self.accountAuthorization == nil else {
				completion("", "credential_unavailable"); return
			}
			guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
				.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) else {
				completion("", "credential_unavailable"); return
			}
			let authorization = SeoriAppleAccountAuthorization(window: window) { [weak self] token, code in
				self?.accountAuthorization = nil
				completion(token, code)
			}
			self.accountAuthorization = authorization
			authorization.start(nonce: nonce)
		}
	}

	deinit {
		// Cancel the update handling task when you deinitialize the class.
		updates?.cancel()
		unfinished?.cancel()
	}

	private func newTransactionListenerTask(transactions: Transaction.Transactions) -> Task<Void, Never> {
		Task(priority: .background) { @Sendable [weak self] in
			for await verificationResult in transactions {
				self?.handle(updatedTransaction: verificationResult)
			}
		}
	}

	private func handle(updatedTransaction verificationResult: VerificationResult<Transaction>) {
		guard case .verified(let transaction) = verificationResult else {
			// Ignore unverified transactions.
			return
		}

		let transData = transactionData(transaction)

		if let revocationDate = transaction.revocationDate {
			// Remove access to the product identified by transaction.productID.
			// Transaction.revocationReason provides details about
			// the revoked transaction.
			transData.transactionState = TransactionState.Refunded.rawValue
			transData.revocationDate = revocationDate
		} else if let expirationDate = transaction.expirationDate,
				  expirationDate < Date() {
			// Do nothing, this subscription is expired.
			return
		} else if transaction.isUpgraded {
			// Do nothing, there is an active transaction
			// for a higher level of service.
			return
		} else {
			// Provide access to the product identified by
			// transaction.productID.
			transData.transactionState = TransactionState.Purchased.rawValue
			transData.purchaseDate = transaction.purchaseDate
		}

		self.transactionCallback(transData)
	}

	private func transactionData(_ transaction: Transaction) -> TransactionData {
		let data = TransactionData()
		if #available(iOS 16.0, *) {
			data.environment = environmentName(transaction.environment)
		} else {
			data.environment = legacyReceiptEnvironment()
		}
		data.productId = transaction.productID
		data.transactionId = String(transaction.id)
		data.originalTransactionId = String(transaction.originalID)
		data.appAccountToken = transaction.appAccountToken?.uuidString.lowercased() ?? ""
		data.purchaseDate = transaction.purchaseDate
		data.revocationDate = transaction.revocationDate
		data.transactionState = transaction.revocationDate == nil
			? TransactionState.Purchased.rawValue
			: TransactionState.Refunded.rawValue
		return data
	}

	@available(iOS 16.0, *)
	private func environmentName(_ environment: AppStore.Environment) -> String {
		if environment == .production { return "production" }
		if environment == .sandbox { return "sandbox" }
		// Local StoreKit transactions cannot be verified by Apple's server API.
		return ""
	}

	private func legacyReceiptEnvironment() -> String {
		// iOS 15 predates AppTransaction. Keep its existing App Store support,
		// using only the system receipt location as a routing hint, never as proof.
		switch Bundle.main.appStoreReceiptURL?.lastPathComponent {
		case "receipt": return "production"
		case "sandboxReceipt": return "sandbox"
		default: return ""
		}
	}

	public func getIapEnvironment() async throws -> String {
		if #available(iOS 16.0, *) {
			guard case .verified(let transaction) = try await AppTransaction.shared else {
				return ""
			}
			return environmentName(transaction.environment)
		}
		return legacyReceiptEnvironment()
	}

	public func test() -> Bool {
		return true;
	}

	public func isProductAvailable(productId: NSString) -> Bool {
		return false;
	}

	public func isProductPurchased(productId: NSString) -> Bool {
		return false;
	}

	private func priceInfoFromProduct(product: Product) -> PriceInfo {
		let info = PriceInfo()
		info.currencyValue = product.price as NSDecimalNumber
		info.localizedDisplay = product.displayPrice
		info.currencyCode = product.priceFormatStyle.currencyCode

		// Get the currency symbol.
		let currencyCode = product.priceFormatStyle.currencyCode
		let locale = product.priceFormatStyle.locale
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencyCode = currencyCode
		formatter.locale = locale
		let currencySymbol = formatter.currencySymbol
		info.currencySymbol = currencySymbol!

		return info
	}

	public func getProductInfo(productId: NSString) async throws -> ProductInfo {
		let productIdentifiers: Set<String> = [productId as String]
		let appProducts = try await Product.products(for: productIdentifiers)
		guard let product = appProducts.first else {
			throw NSError(domain: "GodotStoreKit2Proxy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
		}

		let info = ProductInfo()
		info.productId = product.id
		info.displayName = product.displayName
		info.productDescription = product.description
		info.priceInfo = priceInfoFromProduct(product: product)

		if #available(iOS 18.4, *) {
			for await verificationResult in product.currentEntitlements {
				switch verificationResult {
				case .verified(_):
					info.isPurchased = true
				default:
					info.isPurchased = false
				}
			}
		} else {
			let entitlement = await product.currentEntitlement
			switch entitlement {
			case .verified(_):
				info.isPurchased = true
			default:
				info.isPurchased = false
			}
		}

		return info
	}

	public func getProductPrice(productId: NSString) async throws -> PriceInfo {
		let productIdentifiers: Set<String> = [productId as String]
		let appProducts = try await Product.products(for: productIdentifiers)
		guard let product = appProducts.first else {
			throw NSError(domain: "GodotStoreKit2Proxy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
		}

		return priceInfoFromProduct(product: product)
	}

	public func purchaseProduct(productId: String, appAccountToken: String, quantity: Int) async throws -> TransactionData {
		let productIdentifiers: Set<String> = [productId]
		let appProducts = try await Product.products(for: productIdentifiers)
		guard let product = appProducts.first else {
			throw NSError(domain: "GodotStoreKit2Proxy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
		}

		guard let accountToken = UUID(uuidString: appAccountToken) else {
			throw NSError(
				domain: "GodotStoreKit2Proxy",
				code: 2,
				userInfo: [NSLocalizedDescriptionKey: "appAccountToken must be a UUID"]
			)
		}

		var purchaseOptions: Set<Product.PurchaseOption> = [
			.appAccountToken(accountToken),
		]
		// Apple only permits quantity for product types that support multiple units.
		// The Lizard Tycoon products are NON_CONSUMABLE, so passing quantity there can
		// make StoreKit reject an otherwise valid TestFlight purchase.
		if product.type == .consumable || product.type == .nonRenewable {
			purchaseOptions.insert(.quantity(quantity))
		}
		let result = try await product.purchase(options: purchaseOptions)

		let data = TransactionData()
		data.productId = productId
		switch result{
		case .pending:
			data.transactionState = TransactionState.Pending.rawValue
		case .userCancelled:
			data.transactionState = TransactionState.Canceled.rawValue
		case .success(let verificationResult):
			switch verificationResult {
			case .verified(let transaction):
				// The backend verifies and finishes the transaction through the App Store
				// Server API. Never finish before the authoritative entitlement commit.
				return transactionData(transaction)
			case .unverified(let transaction, let verificationError):
				data.transactionState = TransactionState.Failed.rawValue
				data.transactionId = String(transaction.id)
				data.error = String(describing: verificationError)
			}
		@unknown default:
			data.error = "unknown"
			data.transactionState = TransactionState.Failed.rawValue
		}
		return data
	}

	public func getCurrentEntitlements(productIds: [String]) async throws -> [TransactionData] {
		var transactions: [String: TransactionData] = [:]
		for await verificationResult in Transaction.currentEntitlements {
			if case .verified(let transaction) = verificationResult {
				let data = transactionData(transaction)
				transactions[data.transactionId] = data
			}
		}
		for await verificationResult in Transaction.unfinished {
			if case .verified(let transaction) = verificationResult {
				let data = transactionData(transaction)
				transactions[data.transactionId] = data
			}
		}
		// Refunded non-consumables disappear from currentEntitlements. Query only
		// configured products instead of walking Transaction.all, which can keep
		// app-resume recovery open and block an explicit purchase.
		for productId in Set(productIds) {
			if let verificationResult = await Transaction.latest(for: productId),
			   case .verified(let transaction) = verificationResult {
				let data = transactionData(transaction)
				transactions[data.transactionId] = data
			}
		}
		return transactions.values.sorted { $0.transactionId < $1.transactionId }
	}

	@MainActor
	public func requestRefund(productId: String) async throws -> String {
		guard let verificationResult = await Transaction.latest(for: productId),
			  case .verified(let transaction) = verificationResult,
			  transaction.revocationDate == nil else {
			throw NSError(
				domain: "GodotStoreKit2Proxy",
				code: 3,
				userInfo: [NSLocalizedDescriptionKey: "No refundable transaction found"]
			)
		}
		guard let scene = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.first(where: { $0.activationState == .foregroundActive }) else {
			throw NSError(
				domain: "GodotStoreKit2Proxy",
				code: 4,
				userInfo: [NSLocalizedDescriptionKey: "No foreground window scene found"]
			)
		}

		switch try await transaction.beginRefundRequest(in: scene) {
		case .success:
			return "submitted"
		case .userCancelled:
			return "cancelled"
		@unknown default:
			throw NSError(
				domain: "GodotStoreKit2Proxy",
				code: 5,
				userInfo: [NSLocalizedDescriptionKey: "Unknown refund request status"]
			)
		}
	}

	public func restorePurchases() async throws -> Void {
		try await AppStore.sync()
	}
}

// MARK: - Photo save / share
//
// 게임이 저장한 PNG를 사용자가 실제로 꺼내 볼 수 있는 곳으로 내보낸다.
// 앨범 저장은 add-only 권한(NSPhotoLibraryAddUsageDescription)만 쓰고,
// 공유는 표준 UIActivityViewController를 띄운다. 두 경로 모두 앱 밖으로
// 사진을 전송하지 않는다. 완료 문자열은 빈 값이면 성공, 아니면 실패 사유다.
@objcMembers
public final class GodotPhotoShareProxy: NSObject, @unchecked Sendable {
	public func saveImage(path: String, completion: @escaping @Sendable (String) -> Void) {
		guard let image = UIImage(contentsOfFile: path) else {
			completion("image_load_failed")
			return
		}
		PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
			guard status == .authorized || status == .limited else {
				completion("permission_denied")
				return
			}
			PHPhotoLibrary.shared().performChanges({
				PHAssetChangeRequest.creationRequestForAsset(from: image)
			}, completionHandler: { success, error in
				if success {
					completion("")
				} else {
					completion(error?.localizedDescription ?? "save_failed")
				}
			})
		}
	}

	public func shareImage(path: String, text: String, completion: @escaping @Sendable (String) -> Void) {
		guard FileManager.default.fileExists(atPath: path) else {
			completion("file_missing")
			return
		}
		DispatchQueue.main.async {
			guard let presenter = Self.topViewController() else {
				completion("no_view_controller")
				return
			}
			var items: [Any] = [URL(fileURLWithPath: path)]
			if !text.isEmpty {
				items.append(text)
			}
			let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
			// iPad는 anchor 없이 popover를 띄우면 크래시한다. 화면 하단 중앙에 고정한다.
			if let popover = controller.popoverPresentationController {
				popover.sourceView = presenter.view
				popover.sourceRect = CGRect(
					x: presenter.view.bounds.midX,
					y: presenter.view.bounds.maxY,
					width: 0,
					height: 0
				)
				popover.permittedArrowDirections = []
			}
			controller.completionWithItemsHandler = { _, completed, _, error in
				if let error {
					completion(error.localizedDescription)
				} else {
					completion(completed ? "" : "cancelled")
				}
			}
			presenter.present(controller, animated: true)
		}
	}

	private static func topViewController() -> UIViewController? {
		let scene = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }
			?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
		guard var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
			?? scene?.windows.first?.rootViewController else {
			return nil
		}
		while let presented = top.presentedViewController {
			top = presented
		}
		return top
	}
}

// Keep in sync wit C++ enum.
public enum TransactionState: Int {
	case Failed = 0
	case Refunded = 1
	case Pending = 2
	case Deferred = 3
	case Purchased = 4
	case Restored = 5
	case Expired = 6
	case Canceled = 7
};

@objcMembers
public class PriceInfo: NSObject {
	public var currencyValue: NSDecimalNumber = 0.0
	public var currencyCode = ""
	public var currencySymbol = "$"
	public var localizedDisplay = ""
}

@objcMembers
public class InitializationData: NSObject {
	var initialized: Bool = false;
	public var error = ""
}

@objcMembers
public class TransactionData: NSObject {
	public var environment = ""
	public var productId = ""
	public var transactionId = ""
	public var originalTransactionId = ""
	public var appAccountToken = ""
	public var transactionState = TransactionState.Failed.rawValue
	public var error = ""
	public var purchaseDate: Date? = nil
	public var revocationDate: Date? = nil
}

@objcMembers
public class ProductInfo: NSObject {
	public var productId = ""
	public var displayName = ""
	public var productDescription = ""
	public var isPurchased = false
	public var priceInfo = PriceInfo()
}


@MainActor
private final class SeoriAppleAccountAuthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	private let window: UIWindow
	private var completion: ((String, String) -> Void)?
	private var controller: ASAuthorizationController?
	init(window: UIWindow, completion: @escaping @Sendable (String, String) -> Void) {
		self.window = window; self.completion = completion
	}
	func start(nonce: String) {
		let request = ASAuthorizationAppleIDProvider().createRequest()
		request.nonce = nonce
		// No email or name scopes: only account proof is needed.
		let controller = ASAuthorizationController(authorizationRequests: [request])
		self.controller = controller
		controller.delegate = self; controller.presentationContextProvider = self
		controller.performRequests()
	}
	func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { window }
	func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
		guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
			let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
			finish("", "credential_invalid"); return
		}
		finish(token, "")
	}
	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		finish("", "credential_cancelled_or_unavailable")
	}
	private func finish(_ token: String, _ code: String) {
		let callback = completion; completion = nil; controller = nil
		callback?(token, code)
	}
}
