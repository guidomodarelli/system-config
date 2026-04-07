## Examples

### Revisions route with promise chain

```js
router.get(
  '/roles/users/revisions',
  authorizeByPermissionList(
    ['VIEW_REVISION', 'VIEW_ALL_REVISIONS'],
    KRAKEN_ROLE_MANAGEMENT_APPLICATION_KEY,
  ),
  (req, res) => {
    const {
      query,
      auth: {
        user: { grootId: userId },
      },
    } = req;

    const { status, types, roles } = query;

    const searchParams = {
      page: query.page || DEFAULT_START_PAGE,
      size: query.size || DEFAULT_SIZE,
      from: query.from,
      to: query.to,
      sort: query.sort,
      is_sox: query.is_sox,
      search: query.search,
      status_in: query.status_in,
      status_not_in: query.status_not_in,
    };

    if (status) {
      searchParams.status = status;
    }

    if (types) {
      searchParams.types = types;
    }

    if (roles) {
      searchParams.roles = roles;
    }

    RevalidationsService.getUserRevisions(req, userId, searchParams)
      .then((resp) => {
        res.send(resp);
      })
      .catch((err) => {
        res.status(err.response.status).send(err.response.data);
      });
  },
);
```
