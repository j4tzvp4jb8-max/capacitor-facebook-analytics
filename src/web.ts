import { WebPlugin } from '@capacitor/core';

import type { AdvertiserTrackingStatusResult, FacebookAnalyticsPlugin, PluginVersionResult } from './definitions';

export class FacebookAnalyticsWeb extends WebPlugin implements FacebookAnalyticsPlugin {
  private advertiserTrackingEnabled = true;

  async initAppEvents(): Promise<void> {
    throw this.unimplemented('Facebook Analytics is not available on web.');
  }

  async logEvent(): Promise<void> {
    throw this.unimplemented('Facebook Analytics is not available on web.');
  }

  async logPurchase(): Promise<void> {
    throw this.unimplemented('Facebook Analytics is not available on web.');
  }

  async enableAdvertiserTracking(): Promise<void> {
    this.advertiserTrackingEnabled = true;
  }

  async disableAdvertiserTracking(): Promise<void> {
    this.advertiserTrackingEnabled = false;
  }

  async getAdvertiserTrackingStatus(): Promise<AdvertiserTrackingStatusResult> {
    return {
      status: this.advertiserTrackingEnabled,
    };
  }

  async stopAppEvents(): Promise<void> {
    this.advertiserTrackingEnabled = false;
  }

  async requestTrackingAuthorization(): Promise<{ status: 'authorized' | 'denied' | 'restricted' | 'notDetermined' }> {
    throw this.unimplemented('App Tracking Transparency is iOS only.');
  }

  async getTrackingAuthorizationStatus(): Promise<{ status: 'authorized' | 'denied' | 'restricted' | 'notDetermined' }> {
    throw this.unimplemented('App Tracking Transparency is iOS only.');
  }

  async openAppSettings(): Promise<{ opened: boolean }> {
    throw this.unimplemented('openAppSettings is iOS only.');
  }

  async getPluginVersion(): Promise<PluginVersionResult> {
    return {
      version: 'web',
    };
  }
}
