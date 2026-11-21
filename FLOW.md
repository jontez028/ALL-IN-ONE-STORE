# Project flow

## Build and publish

This is a static website: there is no compile/build command. GitHub Pages serves
the files in the repository directly. Apply the Supabase SQL setup files to the
Supabase project separately.

## How the site is delivered

```mermaid
%%{init: {"themeVariables": {"fontSize": "24px"}, "flowchart": {"nodeSpacing": 55, "rankSpacing": 70}}}%%
flowchart TD
    Repo["Project files"] --> Pages["GitHub Pages"]
    Pages --> Browser["Customer, staff, or admin browser"]
    Browser --> Store["Storefront"]
    Browser --> Legal["Privacy, Terms, and Returns"]
    Legal --> Config["config.js<br/>business details"]
    Store --> ServiceWorker["Service worker"]
    ServiceWorker --> Cache["Static asset cache<br/>offline page fallback"]
    Store --> Supabase["Supabase"]
    ServiceWorker -. "Supabase requests bypass cache" .-> Supabase
    Setup["Supabase SQL setup"] --> Supabase
```

## Customer shopping and checkout

```mermaid
%%{init: {"themeVariables": {"fontSize": "24px"}, "flowchart": {"nodeSpacing": 55, "rankSpacing": 70}}}%%
flowchart TD
    Start["Browse products"] --> Catalogue{"Product source"}
    Catalogue -->|Online| LiveProducts["Supabase products"]
    Catalogue -->|Static mode| StaticProducts["products.json"]
    LiveProducts --> Cart["Product grid and cart"]
    StaticProducts --> Cart
    Cart --> SignIn["Sign up or sign in"]
    SignIn --> Auth["Supabase Auth"]
    Auth --> Profile["Customer profile"]
    Profile --> Checkout["Checkout"]
    Checkout --> Order["Save order"]
    Order --> Orders["Supabase orders table"]
    Orders --> Tracking["Track order"]
    Checkout -. "M-Pesa demo or pay on delivery" .-> Order
```

## Admin and in-store sales

```mermaid
%%{init: {"themeVariables": {"fontSize": "24px"}, "flowchart": {"nodeSpacing": 55, "rankSpacing": 70}}}%%
flowchart TD
    SignIn["Sign in"] --> Auth["Supabase Auth"]
    Auth --> Profile["Profile and role"]
    Profile --> AdminCheck{"Admin?"}
    AdminCheck -->|Yes| Admin["Admin dashboard"]
    Admin --> Products["Manage products"]
    Admin --> Photos["Manage product photos"]
    Admin --> Orders["Review orders and update status"]
    Admin --> Staff["Manage staff access"]
    Profile --> StaffCheck{"Staff or admin?"}
    StaffCheck -->|Yes| POS["In-store POS"]
    POS --> Sale["record_shop_sale RPC"]
    Sale --> Sales["Save sale and update stock"]
    Sales --> Receipt["Receipt and daily sales"]
    Products --> Backend["Supabase"]
    Photos --> Backend
    Orders --> Backend
    Staff --> Backend
    Sale --> Backend
```

The in-store M-Pesa prompt is currently in demo mode; staff enter the customer's
confirmation code manually.
