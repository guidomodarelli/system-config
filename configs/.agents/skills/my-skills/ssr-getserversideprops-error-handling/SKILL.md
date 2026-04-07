---
name: ssr-getserversideprops-error-handling
description: Buenas practicas para manejar errores en SSR con getServerSideProps. Use when working on SSR to wrap API calls in try/catch and return controlled props to keep the UI stable on failures.
---

# SSR getServerSideProps Error Handling

## Quick start
En SSR, encapsula llamadas a APIs en try/catch dentro de getServerSideProps y devolve props controladas cuando falla la dependencia.

## Core workflow
1. En getServerSideProps, envolver cada llamada a API en try/catch.
2. Registrar el error en server logs sin exponer detalles al usuario.
3. Devolver props controladas (fallbacks) para mantener el render estable.
4. Renderizar UI acorde a estados de error o vacios.

## Guidelines
- **try/catch en SSR**: Usar try/catch en getServerSideProps para evitar fallos no controlados.
- **Props controladas**: Devolver props con valores por defecto o flags de error cuando la API falla.
- **No romper el render**: Evitar throw sin manejo que corte el render SSR.
- **Feedback claro**: La UI debe mostrar un estado simple y orientado a la accion.

## Patterns

### API call con props controladas
```
export async function getServerSideProps() {
  try {
    const data = await fetchData();
    return { props: { data, hasError: false } };
  } catch (error) {
    return { props: { data: null, hasError: true } };
  }
}
```

### UI con fallback
```
if (hasError) {
  return <Fallback message="No pudimos cargar los datos. Intenta de nuevo." />;
}
```

## Quick checklist
- Llamadas a APIs en getServerSideProps estan dentro de try/catch.
- Se devuelven props controladas en caso de error.
- La UI renderiza un fallback simple y accionable.
