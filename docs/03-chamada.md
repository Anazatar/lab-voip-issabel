# Fase 2: registo dos softphones e chamada

> **Estado:** feito por mim a 1 de novembro de 2026.
> A chamada entre as duas extensões funcionou. A captura da fase 3
> mostra pacotes de voz nos dois sentidos.

## Configuração

| Extensão | Softphone | Aparelho |
|---|---|---|
| 33006 | MicroSIP 3.22.20 | Windows (192.168.1.138) |
| 33007 | 3CXPhone 6.0 | Windows (192.168.1.138) |

(Versões e associação extensão/softphone tiradas do campo `User-Agent` na
captura da fase 3.)

Servidor SIP configurado nos dois softphones: `192.168.1.64` (VM Issabel), UDP 5060.

## Evidência do registo

Comando corrido na VM com os dois softphones abertos:

```
[root@issabel ~]# asterisk -rx "sip show peers"
Name/username   Host            Dyn Forcerport Comedia  ACL Port   Status
33000           (Unspecified)    D  No         No        A  0      UNKNOWN
33001           (Unspecified)    D  No         No        A  0      UNKNOWN
33003           (Unspecified)    D  No         No        A  0      UNKNOWN
33006/33006     192.168.1.138    D  No         No        A  60903  OK (1 ms)
33007/33007     192.168.1.138    D  No         No        A  54142  OK (107 ms)
sim             172.20.10.10        Auto (No)  No           5060   UNREACHABLE
6 sip peers [Monitored: 2 online, 4 offline Unmonitored: 0 online, 0 offline]
```

## O que o resultado mostra

- As extensões 33006 e 33007 estão registadas (`OK`) e o servidor já sabe
  onde as encontrar: o IP do meu computador, 192.168.1.138.
- Como os dois softphones estão no mesmo computador, têm o mesmo IP. O
  servidor distingue-os pela **porta** de origem (60903 e 54142). Cada
  softphone escolheu uma porta UDP diferente.
- O valor entre parênteses é o tempo de resposta ao pedido de verificação
  (`qualify`) que o Asterisk envia periodicamente. A 33006 respondeu em 1 ms
  e a 33007 em 107 ms, apesar de estarem no mesmo computador. A diferença
  deve vir da forma como cada softphone trata esses pedidos, não da rede.
- As extensões 33000, 33001 e 33003 continuam sem nenhum softphone registado.
