# RK Traders - Inventory & Billing

A grocery store inventory and GST billing system for West Bengal, India.
Runs on your own PC in the browser. Supports many branches and many billing counters.

## How to start

1. Double-click `start.bat`. A black window opens and the browser opens at http://localhost:5000
2. Login with username `admin` and password `admin123`
3. Choose a billing counter and you are in.

Keep the black window open while the shop is running. Close it to stop.

Other computers in the shop on the same Wi-Fi can open the system too. On the main PC, run
`ipconfig` in Command Prompt, find the IPv4 address (for example 192.168.1.5), then on the
other PC open http://192.168.1.5:5000 in the browser.

## First time setup, in this order

1. **Settings** - shop name, address, phone, GSTIN, change the admin password.
2. **Settings > Branches & Counters** - add your branches and counters (Main Branch with Counter 1 already exists).
3. **Settings > Users** - add cashiers and managers and attach each one to a branch.
4. **Products** - add items with GST rate, cost, selling price and opening stock.
   Selling price is GST-inclusive, like MRP.
5. **Suppliers** - optional, for purchase entries.

## Daily use

- **Billing**: type the product name, press Enter, type the quantity, press Enter to go back to search. Press F9 to save and print. The invoice opens in a new tab and the print dialog appears. Prints on A4.
- **Credit (udhaar)**: choose Credit as the payment mode, pick or add a customer, enter the amount paid now. The rest is added to the customer's balance. The bill prints the previous balance, this bill's credit, and the total due.
- **Collecting udhaar**: open Customers > customer name. Enter the amount, mode, and optionally which invoice it is for (default is oldest first). Click Save & print receipt. A numbered receipt voucher (for example MB/RCPT/2627/00007) prints with the invoices it settled and the balance still due. The customer page shows unpaid invoices and a full statement with invoice and receipt numbers. The Receipts menu lists all receipts for the branch.
- **Mistakes**: an admin can cancel a receipt from the Receipts page, which makes the amount due again. A bill that already has a receipt applied cannot be cancelled until that receipt is cancelled first.
- **Purchases**: when a supplier delivers, go to Purchases > New Purchase and enter items. Stock goes up.
- **Stock**: see quantities for the current branch, remove damaged stock with a negative adjustment, transfer stock between branches.
- **Messages** (managers and admins): send a message to another branch and reply in a thread. An unread count shows on the Messages link in the top bar.
- **Stock requests**: Messages > Request stock. Pick the product, see how much each branch has, enter the quantity, and send. The other branch opens it and clicks Send stock, which transfers the quantity immediately and records it in stock history on both sides. They can also Decline with a reason, and you can reopen or close the request.
- **Notices**: a branch manager can send a notice to all staff of their branch or to selected staff. An admin can send to all branches, selected branches, selected staff, or managers only. Everyone sees their notices under Notices in the top bar and on the dashboard until they open them. A popup also appears on every screen, including billing, until the staff member clicks "I have read this" on each notice. If a notice arrives while someone is already logged in, the popup appears within a minute. The sender sees who has read it and when.
- **Leave**: any staff member applies under Leave > Apply for leave with type, dates, reason, and an optional PDF or image document such as a medical certificate. A cashier's application goes to the managers of their branch. A manager's application goes to the admin. The approver gets a notice popup, decides under Leave > Pending approvals, and the applicant gets a notice with the result. Admin can override a manager's decision with a note; the record keeps both the original decision and the override. A pending application can be withdrawn by the applicant.
- **Leave entitlement**: Settings > Leave policy. For each leave type the admin sets days per year (0 means no limit, used for Unpaid) and after how many months of joining it becomes available (0 means immediately). New types can be added. Each user's joining date is set under Users. The apply form shows entitled, used, pending, and remaining days and refuses an application that exceeds the balance or starts before the eligibility date. Entitlement counts per calendar year from approved leave.
- **Device lock**: each user can be locked to one computer. The first login saves the computer's network address (IP). A login from any other address is refused with a message naming the registered device, and the attempt is recorded in the activity log. Admin ticks or unticks "Lock this account to the first device" on the user form, sees the bound address in the Users list, and clicks reset when a computer is replaced. A manager can reset their own branch's cashiers only if admin ticks "Allow this manager to reset device locks" on the manager's record; they then get a Device locks page. Turning a user's lock off forgets the registered device, so turning it on again binds afresh. Admin accounts are not locked by default. Give each counter PC a fixed address in the router (DHCP reservation) so its address does not change.
- **Managers adding cashiers**: under Users, tick "Allow this manager to create and edit cashier users" on a manager. That manager gets a "Cashier users" menu where they can add cashiers of their own branch, reset passwords, and deactivate. They cannot create managers or touch other branches.
- **Activity log** (admin only): every action by every user is recorded automatically with date, time, user, branch, computer address, what was done, the reference such as the bill number, and the submitted details. This covers bills, cancellations, purchases, stock changes, price edits, payments, settings, users, notices, messages, leave, awards, logins, failed logins, logouts, printing, and exports. Passwords are never stored. Open Activity log under Management, default is today, choose any date range, filter by staff or branch, search by text, and export to Excel.
- **Login audit**: every login is recorded with date, time, branch, counter, logout time, and the bills and sales made in that session. If someone closes the browser without logging out, the end time is their last activity and the row is marked "Not logged out". Cashiers see their own history under Login history. Managers see their branch and admin sees everyone under Login audit, by login or as a daily summary, with Excel export.
- **Leaderboard**: ranks staff by sales for today, this week, this month, this year, or custom dates. Cashiers see their own branch. Admin can pick any branch or all branches. Manager or admin can give a prize to anyone on the board; the winner gets a notice popup and the award is listed for the whole branch.
- **Analytics** (admin, or anyone admin grants access under Users with "Allow access to the Analytics dashboard"): growth figures versus the previous equal period, daily sales by branch, 12-month sales and profit, branch comparison, top products, category share, payment mix, busy hours, busy weekdays, cashier performance, slow-moving stock, top customers, and plain-language insights. Admin can view overall or one branch; other viewers see their own branch. Every chart has a Table link underneath. Charts work without internet.
- **Offers** (managers and admin, under Inventory): create a percentage off a product, a special price, buy X get Y free, a percentage off a whole category, or a bill-level offer such as 5% or a flat amount off bills above a threshold. Set the dates, switch it on or off, and for admin choose all branches or one. Live offers apply automatically on the billing screen: items with an offer are tagged OFFER in the search list, the savings show in the totals, and the invoice prints the offer name on each item and "You saved" at the bottom. When several offers match, the customer gets the best one. Managers create offers for their own branch only.
- **Reports**: daily sales, GST summary (for your GST return), item-wise profit, counter-wise sales, purchases, branch comparison. Every report exports to Excel, CSV, and PDF. Each file starts with the company details and the branch details, the report title, the period, and who generated it and when.

## Roles

| Role | Can do |
|---|---|
| Cashier | Billing, view bills, customers, stock view |
| Manager | Cashier rights plus products, purchases, suppliers, stock adjustments, reports |
| Admin | Everything, all branches, settings, users, cancel bills |

## Invoice numbers

Format is `BRANCH/COUNTER/FY/SEQUENCE`, for example `MB/C1/2627/00042`.
Each counter has its own sequence so two counters can bill at the same time.

## Backup

Everything is stored in one file: `rktraders.db`. Copy that file to a pen drive or
cloud folder every day. To restore, copy it back.

## Libraries

Flask (web), openpyxl (Excel), reportlab (PDF). Install with `pip install flask openpyxl reportlab`.

## Files

- `app.py` - the program (Python + Flask)
- `schema.sql` - database tables
- `templates/` - the screens (HTML)
- `static/` - stylesheet and billing screen script
- `rktraders.db` - your data (created on first run)
