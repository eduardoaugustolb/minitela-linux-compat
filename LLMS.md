# Instruções para agentes de IA

Este documento define o procedimento obrigatório para qualquer agente que instale, teste, audite ou corrija a compatibilidade do Minitela neste repositório.

## Princípios e limites

- Este repositório contém apenas scripts e documentação de compatibilidade. Não adicione, faça commit ou publique o `.deb`, binários, recursos, firmware ou quaisquer outros arquivos proprietários da Positivo sem autorização expressa do titular.
- Preserve alterações não relacionadas do usuário e nunca desinstale o Minitela sem solicitação explícita.
- Antes de alterações de sistema, confirme que o pacote fornecido é o `.deb` esperado e que o usuário autorizou a instalação.
- Faça mudanças pequenas, reversíveis e verificáveis. Atualize a documentação quando a instalação ou a compatibilidade mudar.

## Instalação no Fedora

1. Confirme que o pacote existe e é um pacote Debian válido:

   ```bash
   test -f ~/Downloads/minitela_1.0.20_amd64.deb
   ar t ~/Downloads/minitela_1.0.20_amd64.deb
   ```

2. No clone deste repositório, execute o instalador:

   ```bash
   ./scripts/install-fedora.sh ~/Downloads/minitela_1.0.20_amd64.deb
   ```

3. Abra a interface pelo menu **Minitela** ou pelo lançador compatível:

   ```bash
   /usr/local/bin/minitela-show
   ```

   Não use apenas `/usr/share/minitela/minitela` como teste de interface: na primeira execução, o programa do fabricante pode ficar residente e manter a janela oculta.

4. Confirme o básico:

   ```bash
   ldd /usr/share/minitela/minitela | grep 'not found'
   pgrep -af '/usr/share/minitela/minitela'
   /usr/sbin/iwgetid -r
   ```

   O primeiro comando não deve retornar bibliotecas ausentes. O último deve retornar o SSID atual quando houver Wi-Fi conectado.

## Auditoria de falhas

Ao receber um relato de erro, colete primeiro evidências suficientes e reproduza de maneira não destrutiva.

1. Registre ambiente e sessão gráfica:

   ```bash
   cat /etc/os-release
   printf 'session=%s display=%s wayland=%s\n' "$XDG_SESSION_TYPE" "$DISPLAY" "$WAYLAND_DISPLAY"
   rpm -q libayatana-appindicator-gtk3 socat
   ```

2. Registre a saída do aplicativo em arquivo, preservando o terminal do usuário:

   ```bash
   /usr/local/bin/minitela-show
   journalctl --user --since '15 minutes ago' | tail -200
   ```

3. Para problemas de janela, verifique se o processo e o socket interno existem:

   ```bash
   pgrep -x minitela
   ls -l /tmp/minitela_socket
   ```

4. Para hardware, documente o dispositivo conectado sem expor dados pessoais:

   ```bash
   ls -l /dev/ttyACM*
   udevadm info --query=all --name=/dev/ttyACM0
   ```

5. Antes de propor uma correção, determine se ela é específica da distro, da sessão (GNOME/KDE, Wayland/X11), do hardware ou do binário proprietário.

## Erros que podem ser ignorados

Não abra issue para estes avisos isolados, desde que todas as funcionalidades relevantes continuem operando:

- `libayatana-appindicator is deprecated`.
- `libcurl.so.4: no version information available`.
- Avisos de schemas antigos emitidos por `glib-compile-schemas` que não se referem ao schema `org.policorp.minitela`.
- Avisos GTK isolados que não causam janela ausente, crash, falha de interação ou perda de função.

Se um desses avisos vier acompanhado de falha perceptível, ele deixa de ser ignorável e deve ser tratado como evidência na issue.

## Issues no GitHub: obrigatório

**É obrigatório criar uma issue completa e formal no GitHub para cada erro relevante, reproduzível ou potencialmente regressivo antes de encerrar o atendimento.** Isso inclui crash, interface ausente, falha de instalação, biblioteca ausente, incompatibilidade com GNOME/KDE/Wayland/X11, comunicação com o dispositivo, Wi-Fi/Bluetooth/bateria incorretos e corrupção na transferência de GIFs.

Não crie issue apenas para os avisos explicitamente ignoráveis na seção anterior, a menos que tenham impacto funcional.

Use o CLI autenticado, quando disponível:

```bash
gh issue create --repo eduardoaugustolb/minitela-linux-compat --title "[Área] resumo objetivo do problema" --body-file /caminho/para/issue.md
```

Antes de criar, pesquise duplicatas abertas e complemente a existente se for o mesmo defeito:

```bash
gh issue list --repo eduardoaugustolb/minitela-linux-compat --state open --search 'palavras-chave'
```

### Conteúdo obrigatório da issue

1. Título objetivo, com área: `[Instalação]`, `[GNOME]`, `[KDE]`, `[Wayland]`, `[X11]`, `[Hardware]`, `[GIF]` ou equivalente.
2. Resumo do impacto e severidade percebida.
3. Ambiente: distribuição e versão, kernel, desktop, tipo de sessão, versão do pacote Minitela e commit deste repositório.
4. Pré-requisitos e passos mínimos para reproduzir.
5. Resultado esperado e resultado observado.
6. Logs relevantes, em bloco de código, removendo SSID, número de série, tokens, caminhos pessoais e outros dados sensíveis.
7. Frequência, escopo (hardware/sistemas afetados) e possíveis regressões.
8. Hipótese técnica, se houver, claramente identificada como hipótese.
9. Proposta de próximo passo e critério verificável de aceite.

Modelo:

```markdown
## Resumo

## Impacto

## Ambiente
- Distro:
- Kernel:
- Desktop e sessão:
- Minitela:
- Commit do kit:

## Passos para reproduzir
1.
2.

## Resultado esperado

## Resultado observado

## Logs sanitizados
```

## Correção e validação

1. Aplique a menor correção possível no repositório, não diretamente no binário proprietário.
2. Valide a sintaxe e a instalação:

   ```bash
   bash -n scripts/install-fedora.sh scripts/uninstall-fedora.sh
   sh -n scripts/minitela-show scripts/dpkg-query scripts/iwgetid
   ```

3. Teste novamente o caso descrito na issue.
4. Atualize README e este documento se houver mudança de procedimento ou compatibilidade.
5. Faça commit com referência à issue e deixe na issue a evidência de validação, incluindo limitações restantes.

## Próximas frentes recomendadas

- Investigar e reproduzir a corrupção ocasional de GIFs sem publicar mídias ou dados pessoais dos usuários.
- Testar GNOME e KDE Plasma, em Wayland e X11, em máquinas ou ambientes distintos.
- Criar instaladores para outras distribuições RPM após testes reais.
- Solicitar ao fabricante documentação ou autorização caso seja necessário corrigir ou redistribuir o binário diretamente.
