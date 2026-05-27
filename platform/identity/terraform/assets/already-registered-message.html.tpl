<script>
  // Intercept form submission to redirect to home instead of continuing the flow
  document.addEventListener('DOMContentLoaded', function() {
    const form = document.querySelector('form');
    if (form) {
      form.addEventListener('submit', function(e) {
        e.preventDefault();
        window.location.href = '/';
      });
    }
  });
</script>

<div style="text-align: center; padding: 20px; border: 2px solid #333; border-radius: 8px; background-color: #1a1a1a;">
  <h2 style="color: #ffffff;">Account Already Exists</h2>
  <p style="font-size: 16px; margin: 20px 0; color: #ffffff;">
    An account with this email already exists in ${organisation_name} Gateway.
  </p>
  <p style="font-size: 13px; color: #cccccc; margin-top: 20px;">
    If it's yours, please log in. If you've already signed up and your account
    is pending activation, reach out to a delegate.
  </p>
  <button class="pf-c-button pf-m-primary" onclick="window.location.href='/';">Return to Home</button>
</div>
