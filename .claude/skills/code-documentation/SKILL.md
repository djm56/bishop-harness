---
name: code-documentation
description: "Code documentation standards skill covering JSDoc/PHPDoc docblock formats, function parameter documentation, return type documentation, exception documentation, and inline code comments for complex logic. Used by jnr-developer and snr-developer."
---

# Documenting Code

## PHPDoc

```php
/**
 * Brief description of function.
 *
 * Longer description if needed.
 *
 * @since 1.0.0
 *
 * @param string $param_name Description of parameter.
 * @param int    $count      Description of parameter.
 *
 * @return bool Description of return value.
 *
 * @throws \InvalidArgumentException If param_name is empty.
 */
```

## JSDoc

```javascript
/**
 * Brief description of function.
 *
 * @since 1.0.0
 *
 * @param {string} paramName - Description of parameter.
 * @param {number} count     - Description of parameter.
 *
 * @returns {boolean} Description of return value.
 *
 * @throws {Error} If paramName is empty.
 */
```

## Classes

```php
/**
 * Class Brief_Description.
 *
 * Longer description of the class purpose and usage.
 *
 * @since 1.0.0
 *
 * @package Namespace\Package
 */
```

## The Rules

- Public functions, methods, and classes always get a docblock.
- Private and protected methods get one too when the logic isn't trivial.
- `@since` carries a semantic version.
- `@param` on every parameter, with a type and a description.
- `@return` in PHPDoc, `@returns` in JSDoc.
- `@throws` for anything that can be raised.
- Inline comments where a block is genuinely complex — not on self-evident one-liners.
- Say what matters and stop. Filler in a docblock is worse than no docblock.
