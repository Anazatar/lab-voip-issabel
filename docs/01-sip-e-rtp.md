# SIP e RTP: o que acontece numa chamada VoIP

Este resumo serve de base para perceber as capturas do Wireshark deste
laboratório.

## Dois protocolos, duas funções

| Protocolo | Para que serve | Porta habitual | Transporte |
|---|---|---|---|
| SIP | Sinalização: registar o telefone, iniciar, tocar, atender e desligar a chamada | 5060 | UDP (normalmente) |
| RTP | Transportar a voz propriamente dita | Gama alta, combinada na chamada (no Asterisk, por defeito 10000 a 20000) | UDP |
| SDP | Vai dentro das mensagens SIP e diz que codec e que porta RTP cada lado vai usar | (dentro do SIP) | |

O SIP não leva voz. Só combina a chamada. A voz vai depois por RTP,
diretamente nas portas que o SDP anunciou.

## 1. Registo da extensão

Quando o softphone arranca, diz ao servidor "estou aqui, sou a extensão X":

```
Softphone                     Issabel
   | ---- REGISTER ----------->  |
   | <--- 401 Unauthorized ----  |   (o servidor pede autenticação)
   | ---- REGISTER (c/ hash) ->  |   (resposta calculada a partir da password)
   | <--- 200 OK --------------  |
```

O 401 não é um erro: faz parte da autenticação digest. A password não viaja
em texto simples, só um hash calculado a partir dela.

## 2. Chamada entre duas extensões

```
Ext. A              Issabel              Ext. B
  | --- INVITE ------> |                    |
  | <-- 100 Trying --- |                    |
  |                    | --- INVITE ------> |
  |                    | <-- 180 Ringing -- |
  | <-- 180 Ringing -- |                    |
  |                    | <-- 200 OK ------- |   (B atendeu)
  | <-- 200 OK ------- |                    |
  | --- ACK ---------> | --- ACK ---------> |
  |                                         |
  | <========== RTP (voz, nos dois sentidos) =========> |
  |                                         |
  | --- BYE ---------> | --- BYE ---------> |   (A desligou)
  |                    | <-- 200 OK ------- |
  | <-- 200 OK ------- |                    |
```

O RTP pode passar pelo servidor ou ir diretamente entre os telefones,
conforme a configuração (no Asterisk, opção `directmedia`). Isto vê-se na
captura pelos IPs de origem e destino dos pacotes RTP.

## 3. Códigos de resposta mais comuns

| Código | Significado |
|---|---|
| 100 Trying | Pedido recebido, a tratar |
| 180 Ringing | O destino está a tocar |
| 200 OK | Sucesso |
| 401 Unauthorized | Precisa de autenticação |
| 403 Forbidden | Autenticação falhou ou não é permitido |
| 404 Not Found | Extensão não existe |
| 486 Busy Here | Destino ocupado |

## 4. Porque é que isto importa para a segurança

- SIP e RTP vão normalmente **sem cifra**. Quem conseguir capturar o tráfego
  na rede consegue ver quem ligou a quem e até reconstruir o áudio. Para
  cifrar usa-se SIP sobre TLS e SRTP.
- Servidores SIP expostos à Internet recebem muitas tentativas automáticas de
  registo com passwords fracas. Por isso as extensões precisam de passwords
  fortes e o servidor deve bloquear IPs com muitas falhas seguidas.
