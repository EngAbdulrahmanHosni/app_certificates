# 🔐 Android Keystore Vault

This repository manages Android Keystores for all applications.

## 🚀 How to Generate a Keystore

You can generate a new keystore or update an existing one manually via GitHub Actions:

1. Go to the **Actions** tab.
2. Select **Generate Android Keystore** from the sidebar.
3. Click **Run workflow**.
4. Fill in the inputs:
   - **App name**: Folder name under `apps/` (e.g., `my_app`).
   - **Keystore password**: (Optional) Leave empty to checking auto-generate.
   - **Key password**: (Optional) Leave empty to use keystore password.
   - **Verify**: Check to verify the keystore after generation.
   - **Commit changes**: Uncheck if you only want to test without saving.

---
Last updated: 2026-01-05 10:42:51.850986 UTC
