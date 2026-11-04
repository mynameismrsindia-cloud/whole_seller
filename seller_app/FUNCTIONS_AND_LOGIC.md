# Seller App: Features & Logic

## Login and account
- Seller can create an account with name, email, and password, or sign in with email/password.
- The app checks name, email format, and password length (12+ characters for registration); the API enforces account role and credentials.
- A saved session is restored at app start. Access token stays in memory; the refresh token is stored in secure storage and rotated by the API.
- Sign out calls the API to revoke the refresh token and clears the local session. There is no demo-workspace button.

## Sales entry
- The product list is loaded from the API in pages of 50. Use **Load more products** for another page; refresh manually or when returning to the entry tab.
- Products are selected from a dropdown; there is no product search. Inactive and out-of-stock products cannot be selected.
- Store name, contact, location, product, a positive whole-number quantity within displayed stock, and a non-negative whole-number rate are required.
- **Submit Entry** stays grey until these values are valid and becomes green when ready. A submission-in-progress state prevents repeated taps.
- The date and time field displays the device's current local date/time; it is not an editable date picker.
- Each submission includes a unique idempotency key. On success the app clears quantity, retains store details, and reloads products to show updated stock.
- The API computes total as `quantity × rate` and atomically checks/deducts stock with the sale insert. Insufficient stock or inactive products are rejected server-side, even if the app's displayed stock is old.

## Profile and navigation
- **My Profile** displays one card with the signed-in seller's name and email only.
- Bottom navigation switches between **New Entry** and **Profile**; sign out is in the app bar.
- Store name, contact, and location are retained for sales entry; they are not shown on the profile card.

## Connection
- Production API default: `https://wholesellerbackend-production.up.railway.app/api/v1`.
- Set Flutter's `--dart-define=API_BASE_URL=<URL>` to use a different environment, such as a local API.

