// Store backend settings. The anon key is public by design:
// the database rules decide who may read or change anything.
window.AIO={url:"https://qlyefnubijmwkamnldzz.supabase.co",key:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFseWVmbnViaWptd2thbW5sZHp6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4NjQ4MjIsImV4cCI6MjEwODQ0MDgyMn0.C1vUjNYYKooY0TV_DDxTihidkRfyIuOOqmjNhVcZKIE"};

// Business details used on the Privacy, Terms and Returns pages.
// Fill these in, then set draft to false to remove the "draft" banner from those pages.
window.AIO.biz = {
  name: "All In One Store",
  legalName: "",      // the registered business name, as on the certificate
  phone: "0745 384 430",
  email: "",
  address: "",        // shop address
  hours: "",          // opening hours
  returnDays: 7,      // days a customer has to report a problem or return an item
  refundDays: 7,      // working days to pay a refund after a return is approved
  freeDeliveryOver: 15000,
  draft: true
};
