---
name: code-documentation
description: "Language-agnostic docblock standards for every public function, method, class, and meaningful private member. Covers what must be stated, the syntax form for common languages, and when inline comments earn their place. Used by the junior developer (hicks) and senior developer (vasquez)."
---

# Documenting Code

## What Every Docblock Must State

A docblock is a contract between a piece of code and whoever reads it next. It must answer:

1. **What it does** — one line, in plain terms. Not a restatement of the function name.
2. **Every parameter** — name, type if the language requires it, and what that value means. Not just the type alone.
3. **What it returns** — the type and what the return value means, or what the side effect is.
4. **What it can raise, throw, or error with** — the exception type and when it happens.
5. **Side effects** — what the code writes, mutates, calls out to, or persists. If it touches the world, say so.
6. **When to use it** — any constraints, preconditions, or typical context (optional, when it matters).

Every new or changed public function, method, and class gets a docblock. Every private or protected method gets one when the logic isn't trivial. The block lives immediately before the declaration — no separation.

## Inline Comments

Inline comments earn their place when they explain **why** something is done, not when they restate **what** the code does. A line of code that reads as what it is doesn't need to be explained. A line that's doing something non-obvious — a workaround, a performance compromise, a correctness detail — needs a comment that says the reasoning.

Avoid comments that simply repeat the code:

```
# Don't do this
i = i + 1  # increment i

# Do this
i = i + 1  # skip the null entry at position 0
```

## Syntax: Common Forms

The format varies by language and convention. What matters is that the information above is present and clear. Here are a few widely-used forms as examples:

### PHPDoc (PHP)

```php
/**
 * Brief description of what the function does.
 *
 * Longer description if needed, explaining context or non-obvious behaviour.
 *
 * @since 1.0.0
 *
 * @param string $param_name Description of what this parameter means.
 * @param int    $count      Description of what this parameter means.
 *
 * @return bool Description of what the return value means or when true/false.
 *
 * @throws \InvalidArgumentException If param_name is empty.
 */
public function exampleMethod($param_name, $count) {
    // code
}
```

### JSDoc (JavaScript)

```javascript
/**
 * Brief description of what the function does.
 *
 * Longer description if needed, explaining context or non-obvious behaviour.
 *
 * @since 1.0.0
 *
 * @param {string} paramName - Description of what this parameter means.
 * @param {number} count     - Description of what this parameter means.
 *
 * @returns {boolean} Description of what the return value means.
 *
 * @throws {Error} If paramName is empty.
 */
function exampleFunction(paramName, count) {
    // code
}
```

### Docstring (Python)

```python
def example_function(param_name, count):
    """
    Brief description of what the function does.
    
    Longer description if needed, explaining context or non-obvious behaviour.
    
    Args:
        param_name (str): Description of what this parameter means.
        count (int): Description of what this parameter means.
    
    Returns:
        bool: Description of what the return value means or when True/False.
    
    Raises:
        ValueError: If param_name is empty.
    """
    # code
```

## Classes

Every class gets a docblock stating:

- **Purpose** — what the class exists to do
- **Typical usage** — how and when it is instantiated or used
- **Invariants** — what contracts callers can rely on, and what state or behaviour is guaranteed

The docblock syntax follows the same form as the function examples above.

## The Rules

- Public functions, methods, and classes always get a docblock.
- Private and protected methods get one when the logic isn't trivial.
- Version tags (e.g., `@since`, or your language's equivalent) carry a semantic version.
- Every parameter documented: name, type, and meaning. The type alone is not enough.
- Return values documented: what it returns, and what that means.
- Exceptions documented: what can be raised or thrown, and under what condition.
- Inline comments where a block is genuinely complex — explaining **why**, not restating **what**.
- Say what matters and stop. Filler in a docblock is worse than no docblock.
- Syntax varies by language and project convention. Follow what's already there.
