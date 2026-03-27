## Preferred pattern (example)

```js
useEffect(() => {
  const controller = new AbortController();
  let isActive = true;

  async function run() {
    try {
      const data = await fetchSomething({ signal: controller.signal });
      if (!isActive) return;
      setState(data);
    } catch (error) {
      if (!isActive) return;
      if (error?.code === 'ERR_CANCELED' || error?.name === 'CanceledError') return;
      logger.error('MyComponent:fetchSomething failed (id=123)', error);
      setState([]);
    }
  }

  run();

  return () => {
    isActive = false;
    controller.abort();
  };
}, [/* dependencies */]);
```
