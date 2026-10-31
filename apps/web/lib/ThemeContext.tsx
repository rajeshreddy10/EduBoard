'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { getStoredTheme, getStoredAccent, applyTheme, applyAccent, type ThemeId } from './theme';
import { useAuth } from './AuthContext';
import { userProfileService, userSettingsService } from './services/firebaseData';

interface ThemeContextType {
  theme: ThemeId;
  accentColor: string;
  isDark: boolean;
  setTheme: (theme: ThemeId) => void;
  setAccentColor: (color: string) => void;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextType>({
  theme: 'light',
  accentColor: '#3b82f6',
  isDark: false,
  setTheme: () => {},
  setAccentColor: () => {},
  toggleTheme: () => {},
});

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const { user } = useAuth();
  const [theme, setThemeState] = useState<ThemeId>('light');
  const [accentColor, setAccentColorState] = useState<string>('#3b82f6');

  useEffect(() => {
    const storedTheme = getStoredTheme();
    const storedAccent = getStoredAccent();
    setThemeState(storedTheme);
    setAccentColorState(storedAccent);
    applyTheme(storedTheme);
    applyAccent(storedAccent);
  }, []);

  useEffect(() => {
    if (!user?.id || user.id === 'guest' || user.id === 'usr_guest') return;

    // Real-time Firestore sync with userSettings collection (shared across Mobile and Web)
    const unsubSettings = userSettingsService.subscribeToSettings(user.id, (settings) => {
      if (!settings) return;
      const themePreset = settings.themePreset || settings.theme || settings.themeMode;
      if (themePreset && ['light', 'dark', 'midnight', 'sunset', 'emerald', 'cyberpunk'].includes(themePreset)) {
        setThemeState(themePreset as ThemeId);
        applyTheme(themePreset as ThemeId);
      } else if (settings.themeMode === 'dark' || settings.themeMode === 'light') {
        setThemeState(settings.themeMode as ThemeId);
        applyTheme(settings.themeMode as ThemeId);
      }
      if (settings.accentColor) {
        setAccentColorState(settings.accentColor);
        applyAccent(settings.accentColor);
      }
    });

    // Real-time Firestore sync with users collection profile
    const unsubProfile = userProfileService.subscribeToProfile(user.id, (profile: any) => {
      if (!profile) return;
      if (profile.theme && ['light', 'dark', 'midnight', 'sunset', 'emerald', 'cyberpunk'].includes(profile.theme)) {
        setThemeState(profile.theme);
        applyTheme(profile.theme);
      }
      if (profile.accentColor) {
        setAccentColorState(profile.accentColor);
        applyAccent(profile.accentColor);
      }
    });

    return () => {
      if (unsubSettings) unsubSettings();
      if (unsubProfile) unsubProfile();
    };
  }, [user?.id]);

  useEffect(() => {
    const handleThemeChange = () => {
      const currentTheme = getStoredTheme();
      const currentAccent = getStoredAccent();
      setThemeState(currentTheme);
      setAccentColorState(currentAccent);
    };

    window.addEventListener('theme-changed', handleThemeChange);
    window.addEventListener('storage', handleThemeChange);
    return () => {
      window.removeEventListener('theme-changed', handleThemeChange);
      window.removeEventListener('storage', handleThemeChange);
    };
  }, []);

  const handleSetTheme = (newTheme: ThemeId) => {
    setThemeState(newTheme);
    applyTheme(newTheme);
    if (user?.id) {
      console.log('[Firebase Firestore] [Menu Option: Theme Studio] Saving updated theme to Firestore for user:', user.id, newTheme);
      userProfileService.updateProfile(user.id, { theme: newTheme } as any).catch(console.error);
      userSettingsService.saveSettings(user.id, {
        theme: newTheme,
        themePreset: newTheme,
        themeMode: newTheme === 'light' ? 'light' : 'dark',
      }).catch(console.error);
    }
  };

  const handleSetAccent = (color: string) => {
    setAccentColorState(color);
    applyAccent(color);
    if (user?.id) {
      console.log('[Firebase Firestore] [Menu Option: Theme Studio] Saving updated accent color to Firestore for user:', user.id, color);
      userProfileService.updateProfile(user.id, { accentColor: color } as any).catch(console.error);
      userSettingsService.saveSettings(user.id, { accentColor: color }).catch(console.error);
    }
  };

  const toggleTheme = () => {
    const nextTheme: ThemeId = theme === 'dark' ? 'light' : 'dark';
    handleSetTheme(nextTheme);
  };

  const isDark = theme !== 'light';

  return (
    <ThemeContext.Provider
      value={{
        theme,
        accentColor,
        isDark,
        setTheme: handleSetTheme,
        setAccentColor: handleSetAccent,
        toggleTheme,
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  return useContext(ThemeContext);
}
