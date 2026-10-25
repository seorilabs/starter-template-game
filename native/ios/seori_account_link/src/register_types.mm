#include "seori_account_link.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"

static SeoriAccountLink *seori_account_link = nullptr;

void register_seori_account_link_types() {
	// Registered before the Firebase core plugin (ios/plugins order), so App Attest applies to the default app.
	SeoriAccountLink::install_app_check_provider();
	GDREGISTER_CLASS(SeoriAccountLink);
	seori_account_link = memnew(SeoriAccountLink);
	Engine::get_singleton()->add_singleton(Engine::Singleton("SeoriAccountLink", seori_account_link));
}

void unregister_seori_account_link_types() {
	if (seori_account_link != nullptr) {
		memdelete(seori_account_link);
		seori_account_link = nullptr;
	}
}
