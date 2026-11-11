# firetv-button-remap

[English](README.en.md)

**Faça os botões de app do controle do Fire TV abrirem o app que você quiser.**

O controle do Fire TV vem com botões fixos (Prime Video, Netflix, Disney+, Peacock...). Se você não
usa algum desses serviços, o botão fica inútil, ou pior: abre a loja dizendo que o app é
"Indisponível neste país". Este projeto troca o destino desses botões, sem root, sem PC ligado
depois da instalação e sem desinstalar nada da Amazon.

Exemplo do que roda no stick em que foi feito: **Prime Video → Max** e **Peacock → SmartTube**.

## Testado em

| | |
|---|---|
| Aparelho | **Fire TV Stick 4K (2ª geração)**, modelo `AFTKRT` (codinome `karat`) |
| Sistema | **Fire OS 8.1.8.5** (`RS8185/3898`), Android 11, API 30 |
| Controle | Alexa Voice Remote com os botões Netflix, Prime Video, Disney+ e Peacock |
| Junto com | Launcher [FireFrame](https://github.com/dyascj/FireFrame), que também usa um serviço de acessibilidade |
| PC | Windows 11, PowerShell 7, JDK 17 |

Outros aparelhos com **Fire OS 8** (Fire TV Stick 4K Max 2ª geração, Fire TV Cube 3ª geração)
devem funcionar, mas **não foram testados**. No **Fire OS 7** há relatos de que o sistema não
inicia serviços de acessibilidade de terceiros, então provavelmente não funciona. Aparelhos com
**Vega OS** (Fire TV Stick 4K Select) não rodam apps Android e **não são suportados**.

Se você testar em outro aparelho, abra uma issue com o modelo, a versão do Fire OS e o resultado.

## Como funciona

Quando você aperta um botão de app, o Fire OS escreve no log do sistema uma linha que identifica
o botão. Por exemplo, o do Prime Video gera `deeplink_prime_video` e o do Peacock gera
`asin=B08BG9MPT9`. O app `tv.redirect` fica lendo essas linhas e, quando reconhece um botão,
abre o app que você escolheu por cima. Em seguida, por 5 segundos, ele cobre também a tela que a
Amazon abre logo depois (o Prime Video ou a página da loja), para o seu app ficar na frente.

Ele funciona como **serviço de acessibilidade**, o mesmo recurso que os launchers alternativos usam
para pegar o botão Home. É isso que mantém o app rodando e deixa ele abrir outros apps. A
permissão de ler o log (`READ_LOGS`) é dada uma vez pelo ADB.

O app **não tem permissão de internet**, lê apenas as linhas `ActivityTaskManager` do log e não
guarda nada. O código inteiro é [um arquivo Java](src/tv/redirect/ButtonService.java).

> Por que não um app "disfarçado" com o nome do Peacock? Isso foi testado e não funciona: o botão
> pede o app à loja da Amazon pelo código do produto (ASIN), e a loja ignora apps instalados por fora.

## O que você precisa

- Um PC com **Windows 10 ou 11** e **PowerShell**.
- **JDK 17 ou mais novo**, com o `javac` no PATH. Teste com `javac -version`. Se não tiver, instale
  o [Temurin 17](https://adoptium.net/temurin/releases/?version=17).
- O PC e o Fire TV **na mesma rede, e enxergando um ao outro** (veja
  [Solução de problemas](#o-pc-não-encontra-o-fire-tv)).
- Os apps de destino já instalados no Fire TV.

## Instalação passo a passo

### 1. Ligue a depuração ADB no Fire TV

1. **Configurações → Minha Fire TV → Sobre**. Fique em cima do nome do aparelho e aperte OK
   **7 vezes**, até aparecer "Você agora é um desenvolvedor".
2. Volte e entre em **Configurações → Minha Fire TV → Opções do desenvolvedor**.
3. Ligue **Depuração ADB**.

### 2. Anote o IP do Fire TV

**Configurações → Minha Fire TV → Sobre → Rede.** Algo como `192.168.1.24`.

### 3. Baixe este projeto e o Android SDK

Baixe o ZIP do repositório (botão **Code → Download ZIP**) e extraia, ou use `git clone`. Abra o
PowerShell dentro da pasta e rode:

```powershell
.\get-sdk.ps1
```

Ele baixa do Google o adb, as ferramentas de build e a plataforma Android 15 (cerca de 125 MB),
confere o checksum de cada arquivo e guarda tudo em `sdk\`. **Rodar este script significa aceitar a
[licença do Android SDK](https://developer.android.com/studio/terms).**

Se o PowerShell recusar rodar scripts, libere só para esta janela:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

### 4. Conecte ao Fire TV

```powershell
.\sdk\platform-tools\adb.exe connect 192.168.1.24
```

Na TV aparece **"Permitir depuração USB?"**. Marque **"Sempre permitir deste computador"** e
confirme. Rode o comando de novo: tem que aparecer `connected` (ou `already connected`).

### 5. Descubra o texto de cada botão

Os textos que já conhecemos:

| Botão | Texto no log | Testado |
|---|---|---|
| Prime Video | `deeplink_prime_video` | Sim |
| Peacock | `asin=B08BG9MPT9` | Sim |
| Disney+ | `asin=B07Y8SJGCV` | Visto no log; troca não testada |
| Netflix | não tem um texto só dele (veja [Limitações](#limitações)) | Não |

Para outro botão ou outro controle, deixe este comando rodando e aperte o botão:

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 logcat -v brief -s ActivityTaskManager:I
```

Procure a linha `START u0` com `amzns://apps/android?...` que aparece no momento do clique.
Copie um pedaço que só esse botão tenha, como `asin=XXXXXXXXXX` ou `libraryItemId=...`. Aperte
`Ctrl+C` para parar.

### 6. Descubra o nome de pacote dos apps de destino

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 shell pm list packages -3
```

Alguns comuns:

| App | Pacote |
|---|---|
| Max | `com.hbo.hbonow` |
| SmartTube | `org.smarttube.stable` |
| Globoplay | `com.globo.globotv` |
| Netflix | `com.netflix.ninja` |
| Disney+ | `com.disney.disneyplus` |
| Paramount+ | `com.cbs.ca` |

### 7. Instale

As regras ficam no formato `texto do botão>pacote do app`, separadas por `;`:

```powershell
.\install.ps1 -Ip 192.168.1.24 -Rules "deeplink_prime_video>com.hbo.hbonow;asin=B08BG9MPT9>org.smarttube.stable"
```

O script:

1. compila o app com as suas regras e assina com uma chave criada na hora (`redirect.keystore`);
2. instala no Fire TV;
3. concede a permissão de ler o log;
4. liga o serviço de acessibilidade, **sem desligar** outros que você já tenha (como o de um launcher);
5. confirma que o serviço subiu com as regras certas.

No fim aparece `Pronto. ativo com regras {...}`.

### 8. Teste

Aperte cada botão que você trocou. O app novo deve abrir em menos de meio segundo. Pode ser que a
tela da Amazon apareça por um instante antes.

Depois de instalado, o PC não é mais necessário. Você pode até desligar a depuração ADB.

## Mudar as regras

Rode o `install.ps1` de novo com as regras novas, na mesma pasta: ele usa a mesma chave
(`redirect.keystore`) e instala por cima. **Guarde esse arquivo.** Sem ele, para instalar de novo
você precisa desinstalar antes.

## Desinstalar

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 uninstall tv.redirect
```

Os botões voltam ao normal na hora.

## Solução de problemas

### O PC não encontra o Fire TV

Se o `adb connect` dá *timeout* mesmo com o IP certo e a depuração ligada, o roteador
provavelmente está isolando os aparelhos. No stick em que este projeto foi feito, a rede Wi-Fi
`_5G` do roteador da operadora não conversava com o PC ligado no cabo. **Conectar o Fire TV na rede
2.4 GHz** (o mesmo nome sem `_5G`) resolveu. Depois de instalar, ele pode voltar para a 5G. Outra
saída é desligar "Isolamento de AP" ou "AP Isolation" no roteador.

### `unauthorized` ou `Fire TV nao conectado`

Aceite o aviso "Permitir depuração USB?" na TV e rode de novo. Se o aviso não aparecer, desligue e
ligue a Depuração ADB.

### Os botões voltaram a abrir o app original

O Fire OS desliga o serviço depois de algumas atualizações, ou se alguém usar **Forçar parada** no
app em Configurações → Aplicativos. Rode o `install.ps1` de novo.

### `O servico nao iniciou`

Confira se o serviço está na lista:

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 shell settings get secure enabled_accessibility_services
```

Tem que aparecer `tv.redirect/tv.redirect.ButtonService`. Veja também o log do app:

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 logcat -d -s tv-redirect
```

### O botão abre o app certo, mas o original volta por cima

O app cobre a tela da Amazon por 5 segundos. Se um app original demorar mais que isso para
aparecer, abra uma issue com o log do momento do clique.

## Limitações

- **Netflix:** o botão abre o Netflix direto, sem um texto que diferencie o botão de você abrir o
  Netflix pela tela inicial. Trocar esse botão pegaria também esses casos, então não é recomendado.
- **Botões de apps que você tem instalados**, como Disney+: o app original ainda abre por trás, o
  que gasta um pouco de memória. Não testado.
- Depende de como o Fire OS escreve o log. Uma atualização pode mudar o texto de um botão. Nesse
  caso, refaça o passo 5.
- Feito para Windows. Os comandos do Android SDK existem para Linux e macOS, mas os scripts são
  PowerShell e não foram testados fora do Windows.

## Licença

[MIT](LICENSE). Não é afiliado à Amazon. Fire TV, Prime Video e os demais nomes pertencem aos seus donos.
