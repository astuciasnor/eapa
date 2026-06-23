# Prompt para gerar a imagem da estrutura de pastas (Capítulo 3)

Figura: infográfico da **estrutura recomendada de um projeto de análise** no tema
Ocean Gradient — pastas, ícones e o fluxo brutos → limpos → análise → saídas.

> Dicas: poucos rótulos (modelos de imagem erram texto); proporção retrato 4:5;
> alta resolução (≥ 1500 px). Se um rótulo sair torto, gere de novo ou rotule na
> diagramação.

## Estrutura a representar

```
meu_projeto/
├── projeto.Rproj        (abre tudo no RStudio com um clique)
├── README.md            (o mapa do projeto)
├── dados/
│   ├── brutos/          (dados originais — nunca editar)
│   └── limpos/          (dados já tratados)
├── scripts/             (o código .R da análise)
├── imagens/             (figuras e gráficos exportados)
├── resultados/          (tabelas, modelos e saídas)
└── relatorios/          (documentos finais: .qmd, .docx, .pdf)
```

## Prompt principal (PT) — infográfico vetorial

```
Infográfico científico em estilo vetorial plano (flat design), limpo e moderno,
fundo branco, para um livro acadêmico de estatística aplicada à aquicultura.
Tema: a estrutura de pastas recomendada para um projeto de análise de dados em R.

Composição: uma árvore de diretórios estilizada, vertical, com ícones de PASTA
para cada diretório e pequenos ícones de ARQUIVO, organizada assim, de cima para
baixo: "meu_projeto" (pasta raiz) contendo "projeto.Rproj", "README.md", e as
pastas "dados" (com subpastas "brutos" e "limpos"), "scripts", "imagens",
"resultados" e "relatorios".

À direita, uma faixa de FLUXO com 4 passos e setas curvas conectando as pastas:
(1) dados/brutos  ->  (2) dados/limpos  ->  (3) scripts (análise)  ->
(4) imagens + resultados + relatorios (saídas).

Codifique as pastas por cor na paleta Ocean Gradient: dados em azul-marinho
(#0F3B5F), scripts em verde-petróleo (#2E7D8F), imagens/resultados em verde-água
(#62B6B7) e relatorios em âmbar (#E89B3C).

Texto curto e nítido, em PORTUGUÊS, apenas os nomes das pastas/arquivos acima e o
título "Estrutura de um projeto de análise". Nada de texto além disso.

Estilo: design editorial científico, linhas finas, ícones simples de pasta e
arquivo, sombras suaves, tipografia sem serifa limpa, paleta Ocean Gradient
(#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51). Sem fotorrealismo, sem excesso de
detalhes. Proporção retrato 4:5, alta resolução.

Evitar: marca d'água, texto ilegível ou inventado, logotipos, fundo poluído.
```

## Variante em inglês (costuma acertar mais o texto)

```
Clean modern flat-design scientific infographic, white background, for an
academic book on statistics applied to aquaculture. Theme: the recommended folder
structure of an R data-analysis project.

A stylized vertical directory tree with FOLDER icons for each directory and small
FILE icons: root "meu_projeto" containing "projeto.Rproj", "README.md", and the
folders "dados" (with subfolders "brutos" and "limpos"), "scripts", "imagens",
"resultados", "relatorios". On the right, a 4-step FLOW with curved arrows:
dados/brutos -> dados/limpos -> scripts -> imagens + resultados + relatorios.

Color-code folders with the Ocean Gradient palette: dados navy (#0F3B5F), scripts
teal (#2E7D8F), imagens/resultados seafoam (#62B6B7), relatorios amber (#E89B3C).
Short crisp on-image text in PORTUGUESE, only the folder/file names above plus the
title "Estrutura de um projeto de análise".

Style: scientific editorial design, thin lines, simple folder/file icons, soft
shadows, clean sans-serif type, Ocean Gradient palette. No photorealism, no
clutter. Portrait 4:5, high resolution. Avoid watermark, gibberish text, logos.
```

## Onde salvar e como inserir (Quarto)

1. Salve em `eapa/images/estrutura_projeto.png` (PNG, fundo branco, ≥ 1500 px).
2. No capítulo 3, insira:

```markdown
![Estrutura recomendada de um projeto de análise: dos dados brutos, passando
pela limpeza e pelos scripts, até as saídas (imagens, resultados e relatórios).
O projeto que a CatalyseR exporta segue o mesmo espírito, em versão enxuta
(`dados/`, `scripts/`, `relatorios/`).](../../images/estrutura_projeto.png){#fig-estrutura width=80%}
```

3. Referencie no texto com `@fig-estrutura`.

## Nota de entrosamento (para o texto do capítulo)

A CatalyseR, ao **exportar um Projeto R (.zip)**, gera exatamente nesse espírito:
`projeto_analise.Rproj`, `dados/` (dados limpos em `.rda`/`.csv`/`.xlsx`),
`scripts/` (o `.R` da análise + funções) e `relatorios/` (o `.qmd`, o
`custom-reference.docx`) — mais um `README.txt`. A estrutura deste capítulo é a
versão **mais completa**, para os seus próprios projetos; a exportada é o
subconjunto enxuto, pronto para uma análise específica.
