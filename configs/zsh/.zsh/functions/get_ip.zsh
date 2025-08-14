ip4() {
  ip -f inet -4 -json a | jq -r '
    .[]                                       # recorre cada interfaz
    | select(.ifname | test("^eth[0-9]+$"))   # solo eth + número
    | . as $i                                 # guarda la interfaz completa
    | $i.addr_info[]?                         # recorre addr_info (si existe)
    | "\($i.ifname): \(.local)"               # salida “ethX: IPv4”
  '
}
