## Patterns and examples

### Wrapping with context (server and service layers)

```js
throw new Error(
  `role-management: getRole failed (roleId=${roleId}, domainId=${domainId})`,
  { cause: error }
);
```

### Logging with context (client/UI)

```js
logger.error(`RoleDetails:fetchRole failed (roleId=${roleId})`, { error, requestId });
```
