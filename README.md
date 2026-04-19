# Arekta E-Commerce Mobile App

A Flutter-based multi-vendor e-commerce mobile application with role-based authentication for admins, vendors, and clients.

## App Screenshots

### Authentication

**Admin Signup** — Register as an administrator to manage the platform  
![Admin Signup](apk-images/signup-admin.png)

**Vendor Signup** — Register as a vendor to sell products  
![Vendor Signup](apk-images/signup-vendor.png)

**Client Signup** — Register as a customer to browse and purchase  
![Client Signup](apk-images/signup-client.png)

**Vendor Signup Flow** — Post-registration confirmation for vendors  
![Post Vendor Signup](apk-images/post-vendor-signup.png)

### Client Screens

**Home Screen** — Main landing page with featured products and categories  
![Home](apk-images/app-home.png)

**Products Listing** — Browse all available products  
![Products Page](apk-images/products-page.png)

**Product Details** — View product information, images, and pricing  
![Product Details](apk-images/products-detail-screen.png)

**Shopping Cart** — Review selected items before checkout  
![Cart](apk-images/cartscreen.png)

### Admin Screens

**Admin Dashboard** — Overview of platform stats and management options  
![Admin Dashboard](apk-images/admin-dashboard.png)

**Product Approvals** — Review and approve vendor product submissions  
![Product Approvals](apk-images/admin-product-qpprovalscreen.png)

**Vendor Approvals** — Review and approve vendor registration requests  
![Vendor Approvals](apk-images/admin-vendor-approvalscreen.png)

### Vendor Screens

**Vendor Dashboard** — View sales, orders, and platform overview  
![Vendor Dashboard](apk-images/vendor-dashbard.png)

**Product Upload** — Add new products with details and images  
![Product Upload](apk-images/vendor-product-uploadscreen.png)

---

## Features

- Multi-Role Authentication (Admin, Vendor, Client)
- Admin Dashboard with approval management
- Vendor Dashboard with product uploads
- Client: Browse, cart, and purchase products
- Product upload and approval workflow

## Getting Started

```bash
flutter pub get
flutter run
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Android + iOS + Web) |
| Language | Dart ^3.10.7 |
| State Management | Provider ^6.1.5 |
| Backend / Auth | Supabase + GraphQL (supabase_flutter + graphql_flutter) |
| UI | Material + custom widgets (Carousel, ratings, badges, cached images) |