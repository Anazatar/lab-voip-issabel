# Fase 1: levantamento do ambiente

> **Estado:** feito por mim, a 1 de novembro de 2026, com o script
> [`scripts/recolher-info.sh`](../scripts/recolher-info.sh) corrido por SSH na VM.
> Ao colar o script no terminal, o texto dos comandos misturou-se com os
> resultados. Abaixo estão os mesmos resultados, só arrumados por secção.

## Resultados

**Sistema operativo**

```
CentOS Linux release 7.7.1908 (Core)
```

**Versão do Asterisk**

```
Asterisk 16.7.0 built by issabel @ rpm7.issabel.com on a x86_64 running Linux on 2019-12-24 02:14:38 UTC
```

**Drivers SIP carregados**

```
chan_sip.so      Session Initiation Protocol (SIP)   0   Running   extended
chan_pjsip.so    PJSIP Channel Driver                0   Running   core
```

**Extensões (`sip show peers`)**

```
Name/username   Host            Dyn Forcerport Comedia  ACL Port  Status       
33000/33000     (Unspecified)    D  No         No        A  0     UNKNOWN
33001           (Unspecified)    D  No         No        A  0     UNKNOWN
33003/33003     (Unspecified)    D  No         No        A  0     UNKNOWN
sim             172.20.10.10        Auto (No)  No           5060  UNREACHABLE
4 sip peers [Monitored: 0 online, 4 offline Unmonitored: 0 online, 0 offline]
```

**Extensões em PJSIP (`pjsip show endpoints`)**

```
Endpoint:  dummy_endpoint    Unavailable   0 of inf
Objects found: 1
```

**Rede**

```
lo     UNKNOWN   127.0.0.1/8
eth0   UP        192.168.1.64/24
default via 192.168.1.1 dev eth0 proto dhcp metric 100
```

**Serviços e portas**

```
asterisk: active
httpd: active

udp  UNCONN  0  0    *:5060   *:*  users:(("asterisk",...))
tcp  LISTEN  0  128  [::]:443  [::]:*  users:(("httpd",...))
tcp  LISTEN  0  128  [::]:80   [::]:*  users:(("httpd",...))
```

## O que os resultados mostram

**Versões.** O servidor é um Issabel sobre CentOS 7.7 com Asterisk 16.7.0.

**Driver SIP.** Os dois drivers estão carregados, mas as extensões estão
todas no `chan_sip`. No PJSIP só existe um `dummy_endpoint`, que não é uma
extensão real. Por isso, neste laboratório, os comandos certos são os do
`chan_sip` (`sip show peers`, `sip reload`, `sip set debug on`).

**Extensões.** Existem as extensões 33000, 33001 e 33003. Todas aparecem
como `UNKNOWN` e com host `(Unspecified)`, ou seja, nenhum softphone estava
registado no momento do levantamento. A letra `D` indica que o endereço é
dinâmico: o servidor só fica a saber o IP do telefone quando ele se regista.

**Peer `sim`.** Está configurado com o endereço fixo 172.20.10.10 e aparece
`UNREACHABLE`: o Asterisk envia pedidos de verificação para esse IP e não
recebe resposta. Este peer é um trunk SIP criado numa atividade anterior
nas aulas, para fazer chamadas para outro dispositivo na mesma rede. Esse
dispositivo não está presente na rede atual, por isso não responde.

**Extensão 33003.** Extensão de teste criada numa atividade anterior nas
aulas. Não é usada neste laboratório.

**Rede da VM.** A VM tem o IP 192.168.1.64/24, recebido por DHCP do router
192.168.1.1. É a mesma rede do meu computador (192.168.1.138), por isso a
placa de rede da VM está em modo bridged (conclusão tirada do IP; não
verifiquei nas definições do VirtualBox).

**Portas.** O Asterisk escuta SIP em UDP 5060 e a interface web escuta em
HTTP (80) e HTTPS (443).

## Pontos a tratar na fase de segurança

- O CentOS 7 deixou de receber atualizações de segurança a 30 de junho
  de 2024, e o Asterisk 16 também já não recebe correções. Isto não é
  problema num laboratório isolado, mas este servidor nunca deve ficar
  acessível a partir da Internet.
- A porta 80 (HTTP sem cifra) está aberta ao lado da 443. Ver se o Issabel
  redireciona para HTTPS ou se é possível fazer login por HTTP.
- O SIP (5060) está aberto em todas as interfaces, sem filtragem confirmada.
