# Owner Desktop: Features & Logic

## Sign-in and session
- Owner signs in with email and password. There is no public Owner registration; an administrator provisions Owner accounts.
- Login checks email format and non-empty password. The API verifies credentials and Owner role; a non-Owner session is rejected.
- A saved session is restored at app start. The access token stays in memory; the refresh token is stored securely and rotated by the API.
- Sign out revokes the refresh token and clears the local session.

## Products and stock
- The product workspace lists product ID, name, remaining quantity, and active/out-of-stock status.
- Products load from the API in pages (default 50). Search is debounced; manual refresh and page entry refresh the list. **Load more** fetches the next page.
- Owner can add a product (ID, name, initial quantity, active status), edit its name, activate/deactivate it, and add stock.
- Product IDs and names are required; quantity and restock amounts must be whole numbers, with restock strictly positive. Duplicate product IDs are checked before adding.
- Product mutations invalidate the product cache and refresh the list. API-side validation remains authoritative.

## Sales and approval
- Sales list shows date/time, seller, store/contact/location, product, quantity, rate, total, and order status.
- Entries are ordered newest first. Owner can filter by date range, clear the filter, refresh, and load additional pages.
- Total is `quantity × rate`. A pending sale can be approved once; approved sales cannot be changed back to pending. The API enforces Owner authorization and the one-way status transition.
- Sales are submitted by the Seller app; the API records each sale and deducts stock transactionally, rejecting insufficient stock.

## Owner profile and layout
- Owner can edit and save name, store name, contact number, and location. All four fields are required.
- Navigation provides Products, Sales Entries, and Profile. Layout switches between a mobile bottom navigation and a desktop navigation rail based on window width.
- The workspace scrolls to support smaller screens.

## API, pagination, and demo mode
- Production API default: `https://wholesellerbackend-production.up.railway.app/api/v1`; set Flutter `--dart-define=API_BASE_URL=<URL>` to use another environment.
- Product results are briefly cached and simultaneous identical requests are deduplicated. Sales and product lists are paginated rather than downloading all records at once.
- **Open demo workspace** is still available on the login screen. Demo changes use sample in-memory data only and are not saved to the production API.

