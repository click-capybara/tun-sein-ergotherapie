// Apps Script Web App URL — nach dem Deployment hier eintragen
const FORM_ENDPOINT = "https://script.google.com/macros/s/AKfycbxffvwBThuPsrbrQpy7ONeyjWmPJaG55CK6MqMs6SuScoupeasD98j-Ox8npvRmPI4E/exec";

document.addEventListener("DOMContentLoaded", function () {
  const form = document.getElementById("kontaktformular");
  if (!form) return;

  const submitBtn = form.querySelector('button[type="submit"]');
  const originalBtnText = submitBtn.textContent;

  form.addEventListener("submit", function (e) {
    e.preventDefault();

    // Achtung: form.name liefert das name-Attribut des Formulars, nicht das Feld.
    // Deshalb durchgehend über form.elements zugreifen.
    const f = form.elements;

    const data = {
      name: f.name.value.trim(),
      email: f.email.value.trim(),
      phone: f.phone.value.trim(),
      thema: f.thema.value,
      message: f.nachricht.value.trim(),
      consent: f.consent.checked,
      website: f.website ? f.website.value.trim() : ""
    };

    submitBtn.disabled = true;
    submitBtn.textContent = "Wird gesendet …";
    clearFormStatus(form);

    fetch(FORM_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "text/plain;charset=utf-8" }, // avoids CORS preflight to Apps Script
      body: JSON.stringify(data)
    })
      .then(function (response) {
        return response.json();
      })
      .then(function (result) {
        if (result.result === "success") {
          showFormStatus(form, "success", "Vielen Dank! Ihre Anfrage wurde erfolgreich versendet.");
          form.reset();
        } else {
          showFormStatus(form, "error", "Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut oder schreiben Sie uns direkt eine E-Mail.");
        }
      })
      .catch(function () {
        showFormStatus(form, "error", "Etwas ist schiefgelaufen. Bitte versuchen Sie es erneut oder schreiben Sie uns direkt eine E-Mail.");
      })
      .finally(function () {
        submitBtn.disabled = false;
        submitBtn.textContent = originalBtnText;
      });
  });
});

function showFormStatus(form, type, message) {
  const status = document.createElement("p");
  status.className = "form-status form-status-" + type;
  status.textContent = message;
  form.appendChild(status);
}

function clearFormStatus(form) {
  const existing = form.querySelector(".form-status");
  if (existing) existing.remove();
}
