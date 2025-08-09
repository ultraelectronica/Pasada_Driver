# Start Widgets

Stateless/UI-only widgets used by the onboarding / start flow.

* `optimized_welcome_page.dart` – main welcome screen shown on first page of the `PageView`.
* `next_page_button.dart` *(inline in file)* – the arrow button that advances to the login page.
* `welcome_message` *(inline)* – greeting text block.

Widgets here should remain dependency-free (no providers, no business logic) so they can be easily re-used or unit-tested. 