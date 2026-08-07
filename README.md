# Minitela Linux Compatibility Kit

Instalador comunitário para executar o **Minitela Positivo** em Fedora e outros sistemas RPM, sem alterar nem redistribuir o pacote original da Positivo.

## O que este projeto faz

- Extrai localmente o `.deb` oficial fornecido pelo fabricante.
- Instala as dependências Fedora necessárias.
- Corrige as expectativas Debian do aplicativo (`dpkg-query` e `iwgetid`).
- Cria um lançador que mostra a janela mesmo quando o app já está residente na bandeja.
- Funciona em GNOME, KDE Plasma e sessões Wayland através do XWayland quando disponível.

## O que este projeto **não** inclui

Este repositório não contém o executável, arquivos de recursos, firmware ou o pacote `.deb` da Positivo. Eles podem ser proprietários. Baixe o arquivo original por uma fonte autorizada e só publique uma versão modificada caso tenha permissão explícita do detentor dos direitos.

## Instalação no Fedora

1. Baixe o arquivo original, por exemplo `minitela_1.0.20_amd64.deb`.
2. Clone este repositório e execute:

```bash
git clone https://github.com/eduardoaugustolb/minitela-linux-compat.git
cd minitela-linux-compat
./scripts/install-fedora.sh ~/Downloads/minitela_1.0.20_amd64.deb
```

3. Abra **Minitela** pelo menu de aplicativos, ou use:

```bash
/usr/local/bin/minitela-show
```

O instalador solicita `sudo` apenas para instalar dependências e arquivos de sistema.

### Segurança SELinux

O instalador exige SELinux ativo (`Enforcing` ou `Permissive`) e confere os
contextos de `/etc`, `/usr`, `/usr/lib` e `/usr/share` antes e depois da
instalação. Ele usa uma área de estágio controlada em `/var/tmp`, instala uma
lista explícita de arquivos e não copia metadados, ACLs ou xattrs do `.deb`
para diretórios do sistema.

Se o instalador informar que já existem arquivos de uma instalação anterior,
**não force a cópia**. Primeiro restaure/remova essa instalação por um processo
auditado. Em caso de suspeita de corrupção de labels, consulte a issue #2.

Para arquivos udev e fontes deixados pela instalação antiga deste projeto, use
somente a migração verificada abaixo. Ela confere checksum contra o `.deb` e
recusa remover arquivos pertencentes a um RPM ou que tenham sido modificados:

```bash
sudo ./scripts/cleanup-legacy-fedora.sh --apply ~/Downloads/minitela_1.0.20_amd64.deb
```

Depois execute o instalador normal novamente.

## Desinstalação

```bash
./scripts/uninstall-fedora.sh
```

A remoção exige o manifesto criado pelo instalador e recusa apagar arquivos
não rastreados. Isso evita que uma desinstalação apague arquivos do Fedora ou
de outra aplicação.

## Reparação de uma instalação gerenciada

Para aplicar correções de compatibilidade a uma instalação criada por este
projeto, use o fluxo oficial — não copie arquivos para `/usr/local` à mão:

```bash
sudo ./scripts/repair-fedora.sh
```

O reparo só altera arquivos registrados no manifesto da instalação e valida o
resultado antes de concluir.

## Validação dos scripts

```bash
./tests/test-installer-safety.sh
```

O teste estático impede o retorno de cópias arquivadas para `/etc` e `/usr` e
verifica as barreiras básicas de SELinux. A validação completa deve ocorrer em
uma VM/snapshot Fedora com SELinux `Enforcing`.

## Estado de compatibilidade

| Ambiente | Estado | Observação |
| --- | --- | --- |
| Fedora GNOME (Wayland) | Testado | Executa através do XWayland; janela pode ser aberta pelo lançador. |
| Fedora KDE Plasma (Wayland) | Esperado | Depende de XWayland estar instalado e ativo. |
| Fedora GNOME/KDE (X11) | Esperado | Usa o backend GTK X11 diretamente. |
| Outras distros RPM | Planejado | A adaptação principal é portável; faltam instaladores específicos. |

## Limitações conhecidas

- A transferência de GIFs pode apresentar corrupção ocasional. Ainda não há correção; não use para conteúdos importantes sem testar no dispositivo.
- O aplicativo é GTK3 e usa APIs de bandeja antigas. A integração visual pode variar entre ambientes.
- O aviso de versão da `libcurl` é emitido pelo binário do fabricante e, no cenário testado, não impede a operação.

## Como contribuir

Relate a distro, versão, ambiente gráfico, se a sessão é Wayland/X11 e os logs relevantes. Pull requests são bem-vindos para novos instaladores e correções que não redistribuam conteúdo proprietário.

## Licença

Os scripts e a documentação deste repositório são licenciados sob MIT. O software da Positivo continua sujeito à licença do seu fabricante.
