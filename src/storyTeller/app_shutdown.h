#ifndef STORYTELLER_APP_SHUTDOWN__
#define STORYTELLER_APP_SHUTDOWN__

#include <stdbool.h>

static bool app_shutdown_showed = false;

bool app_shutdown_isShowed(void)
{
	return app_shutdown_showed;
}

void app_shutdown_show(void)
{
	app_shutdown_showed = true;
}

void app_shutdown_hide(void)
{
	app_shutdown_showed = false;
}

#endif
