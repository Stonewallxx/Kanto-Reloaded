# Kanto Reloaded Hooks

`KantoReloaded::Hooks.wrap` is the standard way for KR and KR modules to wrap
base instance, global, and singleton methods. It is an alias-based helper, not
a conflict tracker or method replacement registry.

## Instance Methods

```ruby
KantoReloaded::Hooks.wrap(PokemonOption_Scene, :pbUpdate, :my_module_update) do |hook, *args|
  result = hook.call
  MyModule.after_update(self)
  result
end
```

The block runs with the original receiver as `self`. `hook.call` forwards the
original arguments and original block. Its return value is the original method
result. The wrapper block's final value becomes the wrapped method's result.

## Singleton Methods

```ruby
KantoReloaded::Hooks.wrap(GameData, :load_all, :my_module_load, :singleton => true) do |hook, *args|
  result = hook.call
  MyModule.refresh
  result
end
```

## Forwarding Changes

- `hook.call` calls the original method with its original arguments and block.
- `hook.call(new_args...)` replaces the arguments but keeps the original block.
- `hook.call_with(array, block)` explicitly supplies both.
- `hook.call_without_block` forwards the original arguments without the block.
- `hook.receiver`, `hook.arguments`, `hook.block`, and `hook.block_given?` expose
  the original invocation when a wrapper needs to inspect it.

## Guarantees

- Installation is idempotent for the same target, method, and hook ID.
- An inherited alias does not incorrectly mark a subclass as wrapped.
- Public, protected, and private visibility is preserved.
- Instance and singleton methods use the same API.
- Arguments and blocks are forwarded unchanged by `hook.call`.
- Return values are not rewritten by the helper.
- Runtime exceptions from the original method or wrapper are not swallowed.

Use a stable, module-owned hook ID. Do not manually alias base methods in a KR
module when this API can express the wrapper.

## Late Reattachment

If a later script replaces a method outright, the same hook can explicitly
capture that new implementation in another alias generation:

```ruby
KantoReloaded::Hooks.wrap(
  TargetClass,
  :method_name,
  :my_module_hook,
  :reattach => true
) do |hook, *args|
  hook.call
end
```

`KantoReloaded::Hooks.outermost?` reports whether the recorded KR wrapper is
still the outermost implementation. A correctly aliased wrapper from another
mod can make this return `false` while still retaining KR in its original-call
chain, so reattachment is deliberately explicit rather than automatic.
