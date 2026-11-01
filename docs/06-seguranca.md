# Fase 5: segurança básica do servidor

> **Estado:** feito por mim a 1 de novembro de 2026. Cada ponto indica o
> que foi verificado e o que foi corrigido.

O objetivo não é fazer uma auditoria profissional, mas rever os riscos mais
evidentes de um servidor VoIP de laboratório, confirmar se as proteções
existentes funcionam e corrigir o que for simples de corrigir.

## Resumo

| # | Ponto | Estado |
|---|---|---|
| 1 | Software sem suporte (CentOS 7, Asterisk 16, PHP 5.4) | Verificado; não é corrigível no laboratório, fica documentado |
| 2 | HTTP (porta 80) redireciona para HTTPS? | Verificado: sim |
| 3 | O servidor web revela as versões do software | **Corrigido por mim** (Apache e PHP) |
| 4 | Cookie de sessão sem `Secure` e `HttpOnly` | **Corrigido por mim** |
| 5 | fail2ban protege a interface web | Verificado na fase 4 |
| 6 | Passwords das extensões fracas (hash visível no tráfego SIP) | Verificado; não corrigido, recomendação documentada |
| 7 | Trunk `sim` e extensão 33003 de atividades antigas | Verificado; não removidos, recomendação documentada |

## 1. Software sem suporte

Do levantamento da fase 1 e dos cabeçalhos HTTP do ponto 3:

| Componente | Versão | Situação |
|---|---|---|
| CentOS | 7.7 | Sem atualizações de segurança desde 30/06/2024 |
| Asterisk | 16.7.0 | Versão 16 em fim de vida |
| PHP | 5.4.16 | Ramo 5.4 sem suporte há vários anos |
| Apache | 2.4.6 (CentOS) | Dependia das atualizações do CentOS 7 |

Num laboratório isolado na rede local isto é aceitável. Este servidor não
deve ficar acessível a partir da Internet.

## 2. HTTP redireciona para HTTPS

```
PS> curl.exe -I http://192.168.1.64
HTTP/1.1 302 Found
Date: Sun, 01 Nov 2026 14:33:29 GMT
Server: Apache/2.4.6 (CentOS) OpenSSL/1.0.2k-fips PHP/5.4.16
Location: https://192.168.1.64/
Content-Type: text/html; charset=iso-8859-1
```

A porta 80 está aberta, mas o servidor responde `302 Found` e manda o
browser para `https://192.168.1.64/`. Quem abre a interface por HTTP é
levado para HTTPS, e a página de login não é servida sem cifra.

## 3. O servidor revela as versões do software

Na mesma resposta, o cabeçalho `Server` mostra a versão exata do Apache,
do OpenSSL e do PHP. Qualquer pessoa na rede consegue ver isto sem
autenticação, e com as versões é fácil procurar vulnerabilidades
conhecidas.

Esconder a versão não corrige as vulnerabilidades do software antigo, só
deixa de dar essa informação de borla.

### Antes da correção (HTTPS)

```
PS> curl.exe -kI https://192.168.1.64
HTTP/1.1 200 OK
Date: Sun, 01 Nov 2026 14:36:49 GMT
Server: Apache/2.4.6 (CentOS) OpenSSL/1.0.2k-fips PHP/5.4.16
X-Powered-By: PHP/5.4.16
Set-Cookie: issabelSession=(removido); path=/
...
```

A versão aparece em dois cabeçalhos: `Server` (gerado pelo Apache) e
`X-Powered-By` (gerado pelo PHP).

### Correção 1: cabeçalho `Server` (Apache)

Criei um ficheiro de configuração novo, em vez de editar o principal, para
ser fácil de desfazer:

```
[root@issabel ~]# cat > /etc/httpd/conf.d/zz-hardening.conf <<'EOF'
> ServerTokens Prod
> ServerSignature Off
> EOF
[root@issabel ~]# apachectl configtest
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using issabel.local. Set the 'ServerName' directive globally to suppress this message
Syntax OK
[root@issabel ~]# systemctl reload httpd
```

- `ServerTokens Prod` faz o Apache dizer só "Apache", sem versões.
- `ServerSignature Off` tira a versão das páginas de erro geradas pelo Apache.
- O nome começa por `zz-` para ser lido em último lugar, depois das outras
  configurações.
- O aviso `AH00558` não é um erro: o Apache só avisa que não tem um
  `ServerName` definido. A validação terminou com `Syntax OK`.

Para desfazer: apagar o ficheiro e correr `systemctl reload httpd`.

### Depois da correção 1

```
PS> curl.exe -kI https://192.168.1.64
HTTP/1.1 200 OK
Date: Sun, 01 Nov 2026 14:41:11 GMT
Server: Apache
X-Powered-By: PHP/5.4.16
...

PS> curl.exe -I http://192.168.1.64
HTTP/1.1 302 Found
Date: Sun, 01 Nov 2026 14:41:14 GMT
Server: Apache
Location: https://192.168.1.64/
```

O cabeçalho `Server` já não mostra versões. Mas o `X-Powered-By` continua
a revelar a versão do PHP, porque é o PHP que o gera, não o Apache.

### Correção 2: cabeçalho `X-Powered-By` (PHP)

O PHP é configurado no ficheiro `/etc/php.ini`. Fiz uma cópia de segurança
antes de o alterar:

```
cp /etc/php.ini /etc/php.ini.bak
sed -i 's/^expose_php = On/expose_php = Off/' /etc/php.ini
systemctl restart httpd
```

Aqui foi preciso `restart` e não só `reload`, porque o PHP corre dentro do
Apache e só lê o `php.ini` quando o Apache arranca.

Para desfazer: `cp /etc/php.ini.bak /etc/php.ini` e `systemctl restart httpd`.

### Depois da correção 2

```
PS> curl.exe -kI https://192.168.1.64
HTTP/1.1 200 OK
Date: Sun, 01 Nov 2026 14:52:34 GMT
Server: Apache
Set-Cookie: issabelSession=(removido); path=/
Expires: Thu, 19 Nov 1981 08:52:00 GMT
Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0
Pragma: no-cache
Content-Type: text/html; charset=UTF-8
```

O cabeçalho `X-Powered-By` desapareceu. A resposta já não revela nenhuma
versão de software.

## 4. Cookie de sessão sem as proteções `Secure` e `HttpOnly`

Na mesma resposta, o cookie de sessão da interface web é enviado assim:

```
Set-Cookie: issabelSession=...; path=/
```

Faltam-lhe duas proteções habituais:

- **`Secure`**: o browser só envia o cookie por HTTPS. Sem isto, se alguém
  escrever `http://192.168.1.64` com uma sessão aberta, o browser envia o
  cookie sem cifra nesse primeiro pedido, antes de ser redirecionado.
- **`HttpOnly`**: o JavaScript da página não consegue ler o cookie. Se a
  aplicação tiver uma falha de XSS, isto impede que o cookie seja roubado
  por um script.

Quem tiver o cookie de sessão consegue entrar na interface como
administrador, sem precisar da password.

### Correção

As duas opções existem no `/etc/php.ini` (o `php.ini.bak` da correção 2
continua a servir de cópia de segurança):

```
[root@issabel ~]# grep -n -E '^;session.cookie_(secure|httponly)' /etc/php.ini
1364:;session.cookie_secure =
[root@issabel ~]# sed -i -E 's/^;?session.cookie_secure =.*/session.cookie_secure = 1/' /etc/php.ini
[root@issabel ~]# sed -i -E 's/^;?session.cookie_httponly =.*/session.cookie_httponly = 1/' /etc/php.ini
[root@issabel ~]# grep -n -E '^;?session.cookie_(secure|httponly)' /etc/php.ini
1364:session.cookie_secure = 1
1395:session.cookie_httponly = 1
[root@issabel ~]# systemctl restart httpd
```

- O `cookie_secure` estava comentado (com `;` no início), ou seja, inativo.
- No primeiro `grep` escrevi `^;` em vez de `^;?`, por isso só apareceram
  as linhas comentadas. A linha do `cookie_httponly` não apareceu porque
  não estava comentada, e por isso o valor que tinha antes não ficou
  registado. O `sed` encontrou-a na mesma, e o segundo `grep`, já com o
  padrão certo, mostra as duas linhas ativas.

### Depois da correção

```
PS> curl.exe -kI https://192.168.1.64
HTTP/1.1 200 OK
Date: Sun, 01 Nov 2026 15:01:42 GMT
Server: Apache
Set-Cookie: issabelSession=(removido); path=/; secure; HttpOnly
...
```

O cookie passou a ter `secure` e `HttpOnly`. A alteração no `php.ini`
teve efeito, o que mostra que o Issabel usa as definições de sessão do PHP.

Login na interface web depois da alteração: confirmei que continua a funcionar.

## 5. fail2ban protege a interface web

Testado na fase 4: 3 logins falhados em 10 minutos bloqueiam o IP durante
40 minutos. Ver [05-diagnostico-https.md](05-diagnostico-https.md).

## 6. Passwords das extensões SIP

Na fase 3 vi que cada pedido SIP autenticado leva uma `response` MD5
calculada a partir da password. Quem capturar esse tráfego pode testar
passwords offline, sem tocar no servidor, e o fail2ban não o impede.

Avaliação das passwords (`secret`) das extensões 33006 e 33007, feita na
interface web, sem as copiar para aqui:

| | |
|---|---|
| Comprimento | 7 caracteres |
| Composição | 4 letras e 3 números, sem símbolos |

São passwords fracas para este cenário. Com 7 caracteres de letras e
números, o número de combinações possíveis é pequeno o suficiente para
um ataque offline com uma placa gráfica as testar todas em pouco tempo.

Ao contrário de uma password de utilizador, ninguém precisa de decorar a
password de uma extensão: fica guardada no softphone. Por isso pode e deve
ser longa e aleatória.

**Decisão:** neste laboratório não troquei as passwords. Fica registado
como risco identificado. Num ambiente real, a recomendação seria usar
passwords aleatórias com 16 caracteres ou mais em todas as extensões
(por exemplo, geradas com `openssl rand -hex 12`) e atualizá-las nos
softphones.

## 7. Configurações antigas que já não são usadas

O servidor ainda tem configurações de atividades anteriores das aulas:

- **Trunk `sim`**: ligação SIP para outro dispositivo, com o IP fixo
  172.20.10.10. O dispositivo já não está na rede, por isso o Asterisk
  envia pedidos `OPTIONS` sem resposta (30 durante os 78 segundos da
  captura da fase 3).
- **Extensões 33000, 33001 e 33003**: extensões de exercícios anteriores,
  sem nenhum softphone registado.

Num laboratório não fazem mal. Num servidor real, cada extensão ou trunk
que já não é usado é mais uma forma de entrar no sistema (por exemplo,
alguém pode tentar adivinhar a password de uma extensão esquecida) e gera
ruído nos registos. A recomendação seria apagá-los ou desativá-los e
manter só o que está em uso.

**Decisão:** neste laboratório não foram removidos.
