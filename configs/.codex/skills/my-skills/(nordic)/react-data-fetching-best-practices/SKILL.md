---
name: react-data-fetching-best-practices
description: Best practices for React data fetching in MELI/Nordic frontends. Use when adding or updating data flows so data is fetched from a single entry point (prefer a container component), duplicated requests are avoided via shared state, loading/error states show user feedback, and endpoint responses are mapped to props for clean separation of concerns.
---

# React Data Fetching Best Practices

## Quick start
Fetch data once in the container component, share it with child views, handle loading/error feedback, and map endpoint responses into props for clean and reusable views.

## Core workflow
1. Pick a single entry point for data fetching (prefer the container or route-level component).
2. Share fetched data across views instead of re-fetching per view.
3. Track loading and error states and render user feedback for each state.
4. Map endpoint responses to view props to keep UI components focused on rendering.

## Guidelines
- **Single entry point**: Fetch data in one place (container, route component, or hook) and pass it down as props.
- **No duplicate calls**: Reuse shared state or cache results when multiple views need the same data.
- **State feedback**: Always render explicit loading and error feedback, not just empty UI.
- **Endpoint to props**: Normalize or map API responses into view-friendly props to separate data concerns from UI.
- **Separation of concerns**: Keep data fetching logic out of presentational components whenever possible.

## Patterns

### Container fetch with shared props
```
const containerData = useDataQuery();

if (containerData.isLoading) {
  return <LoadingState />;
}

if (containerData.hasError) {
  return <ErrorState />;
}

return <View items={mapItems(containerData.items)} />;
```

### Share data across views
```
const { data } = useSharedData();
return (
  <>
    <ListView items={data.items} />
    <SummaryView stats={data.stats} />
  </>
);
```

### Map endpoint response to props
```
const viewProps = {
  items: response.results,
  total: response.paging.total,
};
```

## Quick checklist
- Single entry point for data fetching is in the container or route component.
- Shared data prevents duplicate requests across views.
- Loading and error states render clear feedback.
- Endpoint responses are mapped to view props.
