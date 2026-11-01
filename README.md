# Laboratório VoIP com Issabel e Asterisk

Central telefónica IP numa máquina virtual, com duas extensões a fazer
chamadas entre si, análise do tráfego SIP e RTP, diagnóstico de um problema
real de acesso e uma revisão de segurança básica do servidor.

Projeto feito no âmbito do CTeSP em Redes e Segurança Informática (IPCA).

## Estado do projeto

| Fase | Estado |
|---|---|
| 1. Levantamento do ambiente (versões, rede, extensões) | Feito por mim (ver [docs/02-ambiente.md](docs/02-ambiente.md)) |
| 2. Registo de dois softphones e chamada entre extensões | Feito por mim (ver [docs/03-chamada.md](docs/03-chamada.md)) |
| 3. Captura da chamada e análise no Wireshark | Feito por mim (ver [docs/04-captura.md](docs/04-captura.md)) |
| 4. Diagnóstico do problema de acesso HTTPS | Feito por mim: reproduzido, diagnosticado e resolvido (ver [docs/05-diagnostico-https.md](docs/05-diagnostico-https.md)) |
| 5. Revisão de segurança básica | Feito por mim: 3 correções aplicadas, restantes riscos documentados (ver [docs/06-seguranca.md](docs/06-seguranca.md)) |

Todos os comandos, resultados e capturas de ecrã deste repositório vêm de
testes que fiz no meu laboratório, a 1 de novembro de 2026. A organização
e a escrita da documentação foram feitas com apoio de IA (Claude), a partir
desses resultados.

## 1. Introdução

O Issabel é uma distribuição Linux que junta o Asterisk (central telefónica
de código aberto) a uma interface web de gestão. Neste laboratório, o
Issabel corre numa VM no VirtualBox, e dois softphones no meu computador
registam-se como extensões e fazem chamadas entre si.

## 2. Objetivo

- Pôr a funcionar uma central telefónica IP numa VM.
- Configurar extensões SIP e fazer chamadas entre elas.
- Perceber, a partir de uma captura real, como funcionam o SIP e o RTP.
- Diagnosticar um problema de acesso ao servidor.
- Rever e melhorar a segurança básica de um servidor VoIP.

## 3. Relação com as unidades curriculares

| Unidade curricular | Ligação ao projeto |
|---|---|
| Serviços de Voz | Issabel, Asterisk, extensões, softphones |
| Comunicações de Dados | SIP, RTP, UDP, análise de pacotes |
| Auditoria Forense de Redes e Sistemas | Captura e interpretação de tráfego |
| Criptografia e Segurança Informática | Autenticação SIP, riscos do tráfego sem cifra, proteção do servidor |
| Administração de Redes e Sistemas | VM, rede no VirtualBox, serviços Linux, Apache, fail2ban |

## 4. Ferramentas utilizadas

- VirtualBox
- Issabel sobre CentOS 7.7, com Asterisk 16.7.0 (extensões em `chan_sip`)
- Softphones: MicroSIP e 3CXPhone
- tcpdump e Wireshark
- fail2ban e iptables
- Comandos de diagnóstico: `ping`, `curl`, `systemctl`, `Test-NetConnection`

## 5. Ambiente

```
                  Router 192.168.1.1
                         │
        ─────────── rede 192.168.1.0/24 ───────────
          │                               │
 Windows (anfitrião)               VM Issabel (VirtualBox,
 192.168.1.138                     placa em modo bridged)
 MicroSIP (ext. 33006)             192.168.1.64
 3CXPhone (ext. 33007)             Asterisk 16.7.0, SIP UDP 5060
 Wireshark                         Interface web: 80 / 443
```

## 6. O que foi feito

- [docs/01-sip-e-rtp.md](docs/01-sip-e-rtp.md): como funcionam o SIP e o RTP (base teórica)
- [docs/02-ambiente.md](docs/02-ambiente.md): levantamento do servidor (versões, extensões, rede, portas)
- [docs/03-chamada.md](docs/03-chamada.md): registo dos softphones e chamada entre extensões
- [docs/04-captura.md](docs/04-captura.md): captura da chamada, fluxo SIP, codecs e RTP
- [docs/05-diagnostico-https.md](docs/05-diagnostico-https.md): bloqueio do meu IP pelo fail2ban e como o resolvi
- [docs/06-seguranca.md](docs/06-seguranca.md): revisão de segurança básica do servidor

## 7. Comandos e configurações importantes

Consola do Asterisk:

```
asterisk -rvvv          # entrar na consola
core show version       # versão do Asterisk
sip show peers          # extensões registadas (chan_sip)
sip reload              # recarregar configuração SIP
```

Captura de tráfego VoIP no servidor:

```
tcpdump -i eth0 -n -w /root/chamada.pcap 'udp port 5060 or udp portrange 10000-20000'
```

fail2ban:

```
fail2ban-client status                          # listar jails
fail2ban-client status issabel-gui              # IPs bloqueados na interface web
fail2ban-client set issabel-gui unbanip <IP>    # desbloquear um IP
```

Levantamento do ambiente: [scripts/recolher-info.sh](scripts/recolher-info.sh)
(só lê informação, não altera nada).

## 8. Testes realizados e resultados

| Teste | Resultado |
|---|---|
| Registo das extensões 33006 e 33007 | Ambas `OK` no `sip show peers` |
| Chamada da 33007 para a 33006 | Atendida, cerca de 11,6 s, fluxo SIP completo |
| Áudio (RTP) | 4 fluxos G.711 A-law, 0 pacotes perdidos, jitter abaixo de 2 ms |
| Acesso HTTPS durante bloqueio do fail2ban | Ping OK, porta 443 recusada (regra `REJECT`) |
| Acesso HTTPS depois do desbloqueio | Porta 443 OK |
| HTTP (porta 80) | Redireciona para HTTPS (`302`) |
| Versões nos cabeçalhos HTTP | Removidas (`Server: Apache`, sem `X-Powered-By`) |
| Cookie de sessão | Passou a ter `secure` e `HttpOnly`; login continua a funcionar |

## 9. Dificuldades encontradas

- **Perdi o acesso à interface web.** Depois de várias passwords erradas
  no login, o fail2ban bloqueou o IP do meu computador. Identifiquei a
  causa no servidor e desbloqueei o IP. Detalhes em
  [docs/05-diagnostico-https.md](docs/05-diagnostico-https.md).
- **Esconder as versões do servidor web exigiu duas alterações.** A
  configuração do Apache tirou a versão do cabeçalho `Server`, mas o PHP
  continuava a mostrá-la no `X-Powered-By`, que é configurado noutro
  ficheiro (`php.ini`).

## 10. O que aprendi

- Quando um serviço deixa de responder, testar primeiro a rede (ping) e
  depois a porta do serviço ajuda a separar um problema de rede de um
  problema no servidor.
- O fail2ban protege o servidor contra tentativas repetidas de login, mas
  também pode bloquear utilizadores legítimos. É preciso saber consultar e
  desbloquear IPs.
- Numa chamada VoIP, o SIP e o RTP vão sem cifra, e a autenticação deixa um
  hash que pode ser atacado. Por isso uma captura de tráfego VoIP é
  informação sensível.

## Limitações

- O servidor usa software sem suporte (CentOS 7, Asterisk 16, PHP 5.4).
  Serve para laboratório, não para produção.
- As passwords das extensões são curtas e não foram trocadas (ver ponto 6
  de [docs/06-seguranca.md](docs/06-seguranca.md)).
- A captura `.pcap` não é publicada porque contém áudio e hashes de
  autenticação.
