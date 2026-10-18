# Manual runtime validation — two local peers

Este roteiro é um plano de teste, **não evidência de que o runtime já foi aprovado**. Requer Godot 4.3+ e deve ser acompanhado de logs/capturas reais.

## Abrir o projeto

Na raiz do projeto, execute `INICIAR_BLACKSITE.bat`. Ele abre o editor; na primeira execução aguarde o import completo e confirme que a cena principal abre com F5. Depois feche a janela do jogo/editor antes do teste em duas instâncias runtime abaixo (ou use F5 no editor para o host e inicie somente o cliente pelo segundo comando). A cena principal configurada é `res://scenes/menu/main_menu.tscn`. Não pule o primeiro import do editor em um checkout novo.

## Duas instâncias no Windows (PowerShell)

Abra duas janelas PowerShell no diretório que contém `project.godot`. Em cada janela, obtenha o executável instalado. Se Godot estiver no PATH:

```powershell
$godot = (Get-Command godot.exe -ErrorAction SilentlyContinue).Source
```

Se não estiver no PATH, substitua a string abaixo pelo caminho completo **real** do seu executável Godot console; o projeto não presume pasta de instalação:

```powershell
$godot = (Resolve-Path 'CAMINHO_REAL\Godot_v4.x-stable_win64_console.exe').Path
```

Confira `$godot` e a versão com `& $godot --version`. Repita a atribuição em cada janela PowerShell (as variáveis não são compartilhadas entre janelas).

Janela PowerShell 1 — host, mantendo o console visível e salvando saída:

```powershell
$project = (Resolve-Path .).Path
& $godot --path $project --position 100,100 2>&1 | Tee-Object -FilePath .\blacksite-host.log
```

No menu da primeira instância clique **HOSPEDAR PARTIDA** (UDP `24560`).

Janela PowerShell 2 — cliente:

```powershell
$project = (Resolve-Path .).Path
& $godot --path $project --position 700,100 2>&1 | Tee-Object -FilePath .\blacksite-client.log
```

Na segunda instância deixe IP `127.0.0.1`, porta `24560`, e clique **ENTRAR NA PARTIDA**. Se `--position` não funcionar nessa versão, organize as janelas manualmente. Se preferir a interface do editor para o host, abra o editor na primeira instância e pressione F5; rode o comando cliente no segundo PowerShell.

## Verificações e resultados a registrar

1. A primeira instância hospeda sem erro de bind/porta e entra no setor.
2. O segundo peer conecta; ambas as janelas mostram dois IDs no roster.
3. Movimente os dois personagens simultaneamente com WASD e mouse. Confirme que cada câmera/controlador é local e os dois avatares aparecem sincronizados.
4. Caminhe contra paredes e a caixa GLB; verifique colisões em ambas as instâncias. Depois aproxime os dois avatares para testar colisão entre personagens.
5. Feche o cliente; o host deve remover o ID e continuar na partida. Reabra o cliente para repetir. Encerre o host e verifique se o cliente retorna ao menu com mensagem de desconexão.
6. Inspecione `blacksite-host.log` e `blacksite-client.log` por `SCRIPT ERROR`, falhas de RPC e erros críticos de física/import. Preserve as mensagens e passos de reprodução reais.
7. Para limite da sala, inclua clientes adicionais: esperado um host + três clientes; o quinto jogador total deve ser recusado/desconectado.

Registre versão exata do Godot, passos, saída, capturas de tela reais e resultado individual de cada item. Este teste local **não** valida LAN nem internet. Para LAN, use IP privado do host e permita UDP 24560 no firewall. Internet requer hospedagem UDP alcançável/encaminhamento de porta, e CGNAT pode impedir entrada.

## Linux/macOS (se Godot estiver no PATH)

Em dois terminais no diretório do projeto: `godot --path . --position 100,100` e `godot --path . --position 700,100`; clique hospedar na primeira e conecte `127.0.0.1:24560` na segunda.
