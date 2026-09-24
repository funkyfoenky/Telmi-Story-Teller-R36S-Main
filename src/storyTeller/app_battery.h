#ifndef STORYTELLER_BATTERY__
#define STORYTELLER_BATTERY__

#include <stdbool.h>
#include "system/battery.h"
#include "SDL2/SDL.h"

/* 3150 mV ≈ 0 % OCV R36S, au-dessus du cutoff kernel 3000 mV (UI avant PMIC).
 * 3530 mV (U-Boot Odroid) ≈ 35 % OCV ici — trop tôt sous charge. */
#define APP_BATTERY_CRIT_MV 3150
#define APP_BATTERY_CRIT_PCT 5
#define APP_BATTERY_SOC_GUARD_MV 3600
#define APP_BATTERY_CONFIRM_MS 4000
#define APP_BATTERY_LOW_HOLD_MS 3000

static int app_battery_percentage = -1;
static int app_battery_voltage_mv = -1;
static Uint32 app_battery_next_ms;
static Uint32 app_battery_crit_since_ms;
static Uint32 app_battery_low_shown_ms;
static bool app_battery_low_showed;

static void app_battery_refresh(void)
{
	Uint32 now = SDL_GetTicks();

	if (app_battery_percentage >= 0 && now < app_battery_next_ms)
		return;

	app_battery_next_ms = now + 2000;
	app_battery_percentage = battery_getPercentage();
	if (app_battery_percentage < 0)
		app_battery_percentage = 0;
	if (app_battery_percentage > 100)
		app_battery_percentage = 100;
	app_battery_voltage_mv = battery_getVoltageMv();
}

static int app_battery_getPercentage(void)
{
	app_battery_refresh();
	return app_battery_percentage;
}

static int app_battery_getVoltageMv(void)
{
	app_battery_refresh();
	return app_battery_voltage_mv;
}

static bool app_battery_isCriticalNow(void)
{
	int mv;
	int pct;

	if (battery_isCharging())
		return false;

	app_battery_refresh();
	mv = app_battery_voltage_mv;
	pct = app_battery_percentage;

	if (mv > 0 && mv < APP_BATTERY_CRIT_MV)
		return true;
	if (pct >= 0 && pct <= APP_BATTERY_CRIT_PCT &&
	    (mv <= 0 || mv < APP_BATTERY_SOC_GUARD_MV))
		return true;
	return false;
}

static bool app_battery_shouldShutdown(void)
{
	Uint32 now = SDL_GetTicks();

	if (!app_battery_isCriticalNow()) {
		app_battery_crit_since_ms = 0;
		return false;
	}
	if (app_battery_crit_since_ms == 0)
		app_battery_crit_since_ms = now ? now : 1;
	return (now - app_battery_crit_since_ms) >= APP_BATTERY_CONFIRM_MS;
}

bool app_battery_low_isShowed(void)
{
	return app_battery_low_showed;
}

void app_battery_low_show(void)
{
	if (app_battery_low_showed)
		return;
	app_battery_low_showed = true;
	app_battery_low_shown_ms = SDL_GetTicks();
	if (app_battery_low_shown_ms == 0)
		app_battery_low_shown_ms = 1;
}

bool app_battery_low_holdExpired(void)
{
	if (!app_battery_low_showed)
		return false;
	return (SDL_GetTicks() - app_battery_low_shown_ms) >= APP_BATTERY_LOW_HOLD_MS;
}

#endif
