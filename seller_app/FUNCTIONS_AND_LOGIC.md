# Seller App: Features & Logic

## Login and account
- Seller can create an account with name, email, and password, or sign in with email/password.
- The app checks name, email format, and password length (12+ characters for registration); the API enforces account role and credentials.
- Password visibility can be toggled. Opting into **Remember password** saves the email and password in OS-backed secure storage on this device.
- A saved session is restored at app start. Access token stays in memory; the refresh token is stored in secure storage and rotated by the API.
- Sign out calls the API to revoke the refresh token and clears the local session. There is no demo-workspace button.

## Sales entry
- The product list is loaded from the API in pages of 50. Use **Load more products** for another page; refresh manually or when returning to the entry tab.
- Each sale can contain up to 10 different products. Add/remove controls manage product rows; each row requires a product, positive whole-number quantity within displayed stock, and non-negative whole-number rate. A product cannot be repeated in the same sale.
- Products are selected from dropdowns; there is no product search. Inactive and out-of-stock products cannot be selected.
- Store name, contact, and location are required for the whole sale.
- **Submit Entry** stays grey until these values are valid and becomes green when ready. A submission-in-progress state prevents repeated taps.
- The date and time field displays India Standard Time (IST); it is not an editable date picker.
- Each submission includes a unique idempotency key shared by all product rows. On success the app clears the sale rows, retains store details, and reloads products to show updated stock.
- The API computes each line total as `quantity × rate` and atomically checks/deducts stock and inserts every line in one transaction. If any product is unavailable or has insufficient stock, the entire sale is rejected without partial stock changes.

## Profile and navigation
- **My Profile** displays one card with the signed-in seller's name and email only.
- Bottom navigation switches between **New Entry** and **Profile**; sign out is in the app bar.
- Store name, contact, and location are retained for sales entry; they are not shown on the profile card.

## Connection
- Production API default: `https://wholesellerbackend-production.up.railway.app/api/v1`.
- Set Flutter's `--dart-define=API_BASE_URL=<URL>` to use a different environment, such as a local API.
