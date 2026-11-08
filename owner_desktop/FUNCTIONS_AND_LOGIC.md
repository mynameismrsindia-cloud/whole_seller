# Owner Desktop: Features & Logic

## Sign-in and session
- Owner signs in with email/password or registers with name, email, and password, like a Seller. Owner registration uses its own API endpoint and assigns the Owner role.
- Login checks email format and non-empty password. The API verifies credentials and Owner role; a non-Owner session is rejected.
- Password visibility can be toggled. Opting into **Remember password** saves the email and password in OS-backed secure storage on this device.
- A saved session is restored at app start. The access token stays in memory; the refresh token is stored securely and rotated by the API.
- Sign out revokes the refresh token and clears the local session.

## Products and stock
- The product workspace lists product name first, remaining quantity, and active/out-of-stock status; generated product IDs are kept internal and not shown in the list.
- Products load from the API in pages (default 50). Search is debounced; manual refresh and page entry refresh the list. **Load more** fetches the next page.
- Owner can add a product (ID, name, initial quantity, active status), edit its name, activate/deactivate it, and add stock.
- Product IDs are generated as unique, six-character hexadecimal codes and are not shown in the product list. The Owner app includes a generated compatibility ID for older API deployments; the updated API generates and returns its own ID. Owners enter the product name and initial quantity; restock amounts must be whole numbers and strictly positive.
- Product mutations invalidate the product cache and refresh the list. API-side validation remains authoritative.

## Sales and approval
- Sales list shows Indian date/time, seller, store/contact/location, product, quantity, rate, and order status. User IDs are not shown; the total column is omitted.
- Entries are ordered newest first. Owner can filter by date range, clear the filter, refresh, and load additional pages.
- Each sale row has a PDF action that downloads an invoice with the sale ID, date/time, seller, store/contact/location, product, quantity, rate, total, and order status.
- Total is `quantity × rate`. A pending sale can be approved once; approved sales cannot be changed back to pending. The API enforces Owner authorization and the one-way status transition.
- After approval succeeds, the row immediately changes to an Approved badge and its approval action is disabled.
- Sales are submitted by the Seller app; the API records each sale and deducts stock transactionally, rejecting insufficient stock.

## Account and layout
- The Profile page has been removed. The desktop navigation shows the signed-in owner's logo, name, and email, with Log out at the bottom.
- Navigation provides Products and Sales Entries and adapts to the available window width.
- The desktop workspace scrolls vertically; wide Products and Sales tables have their own always-visible, draggable horizontal scrollbars.

## API and pagination
- Production API default: `https://wholesellerbackend-production.up.railway.app/api/v1`; set Flutter `--dart-define=API_BASE_URL=<URL>` to use another environment.
- Product results are briefly cached and simultaneous identical requests are deduplicated. Sales and product lists are paginated rather than downloading all records at once.
- The app requires a valid Owner account; there is no demo workspace.
