#!/bin/bash
# recolher-info.sh
# Recolhe informação básica do servidor Issabel para documentar o laboratório.
#
# Só LÊ informação, não altera nada no servidor.
# Não mostra passwords das extensões nem endereços MAC.
#
# Uso (como root, na consola do Issabel ou por SSH):
#   bash recolher-info.sh

echo "===== Sistema operativo ====="
cat /etc/redhat-release 2>/dev/null || cat /etc/os-release | head -2

echo
echo "===== Versão do Asterisk ====="
asterisk -rx "core show version"

echo
echo "===== Drivers SIP carregados (chan_sip e/ou PJSIP) ====="
asterisk -rx "module show like chan_sip"
asterisk -rx "module show like chan_pjsip"

echo
echo "===== Extensões registadas ====="
# Só um destes comandos vai mostrar as extensões, depende do driver usado.
asterisk -rx "sip show peers" 2>/dev/null
asterisk -rx "pjsip show endpoints" 2>/dev/null | head -30

echo
echo "===== Endereços IPv4 (sem MAC) ====="
ip -4 -br addr

echo
echo "===== Rota por defeito ====="
ip route | grep default

echo
echo "===== Estado dos serviços ====="
for s in asterisk httpd; do
    echo "$s: $(systemctl is-active $s)"
done

echo
echo "===== Portas à escuta (SIP, web) ====="
ss -tulnp | grep -E ':(5060|5061|5066|80|443)\b'
