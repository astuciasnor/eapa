# Prompt para gerar a imagem do experimento (Capítulo 11 — ANOVA)

Figura: infográfico do experimento de comparação de **quatro rações iso-proteicas
para bagres** (Tabela 7.4, Bhujel 2011) — delineamento inteiramente casualizado
(DIC): tanque único, gaiolas-rede, 4 tratamentos (A–D), réplicas, pesagem → ANOVA.

> Dica geral: modelos de imagem ainda erram texto. Mantenha **poucos rótulos** e,
> se algum sair torto, gere de novo ou deixe para rotular na diagramação do livro
> (a legenda da figura já carrega a explicação). Peça **proporção retrato 4:5** e
> alta resolução (≥ 1500 px).

---

## Prompt principal — infográfico vetorial (recomendado), em português

```
Infográfico científico em estilo vetorial plano (flat design), limpo e moderno,
fundo branco, para um livro acadêmico de estatística aplicada à aquicultura.
Tema: experimento comparando quatro rações comerciais para bagres (catfish /
Ictalurus, peixes com barbilhões), em delineamento inteiramente casualizado.

Composição em vista isométrica suave:
- Ao centro, UM único tanque/viveiro de aquicultura de grande porte, visto de
  cima em leve perspectiva, água em tons de azul-petróleo.
- Dentro do tanque, uma grade de gaiolas-rede flutuantes (cages de malha)
  organizadas em 4 colunas por 5 linhas (cerca de 20 gaiolas). Cada COLUNA é uma
  ração, codificada por cor: A azul-marinho (#0F3B5F), B verde-petróleo (#2E7D8F),
  C verde-água (#62B6B7), D âmbar (#E89B3C).
- Cardumes estilizados de bagres dentro das gaiolas (sugerir ~50 peixes por gaiola).
- No píer, quatro sacos/baldes de ração rotulados A, B, C, D, com ícones de
  grânulos (pellets), indicando rações iso-proteicas com níveis diferentes de lipídio.
- Uma pesquisadora (silhueta estilizada) pesando um peixe numa balança digital,
  com leitura em gramas.
- Faixa inferior com 4 passos e setas: (1) preparar gaiolas e estocar 50 peixes,
  (2) alimentar com cada ração, (3) pesar o peso final em gramas, (4) comparar as
  médias com ANOVA — mostrar um pequeno boxplot em que a ração C é a mais alta.

Texto curto e nítido, em PORTUGUÊS, apenas estes rótulos:
título "Experimento: 4 rações iso-proteicas para bagres"; "Tanque único";
"4 rações (A, B, C, D)"; "5 réplicas por ração"; "50 peixes por gaiola";
"Pesagem final (g)"; "ANOVA". Nada de texto além desses.

Estilo: design editorial científico, linhas finas, ícones simples, sombras
suaves, paleta Ocean Gradient (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51),
tipografia sem serifa limpa. Sem fotorrealismo, sem excesso de detalhes.
Proporção retrato 4:5, alta resolução.

Evitar: marca d'água, texto ilegível ou inventado, logotipos, fundo poluído,
peixes irreais, aparência 3D pesada.
```

---

## Variante em inglês (costuma renderizar o texto com mais precisão)

```
Clean modern flat-design scientific infographic, white background, for an
academic book on statistics applied to aquaculture. Theme: an experiment
comparing four commercial iso-protein feeds for catfish (Ictalurus, whiskered
fish), in a completely randomized design.

Soft isometric view:
- Center: ONE single large aquaculture pond seen from a slight top angle, teal
  water.
- Inside it, a grid of floating net cages arranged in 4 columns by 5 rows (~20
  cages). Each COLUMN is one feed, color-coded: A navy (#0F3B5F), B teal
  (#2E7D8F), C seafoam (#62B6B7), D amber (#E89B3C).
- Stylized schools of catfish inside the cages (~50 fish per cage).
- On the pier, four feed sacks/buckets labeled A, B, C, D with pellet icons
  (iso-protein feeds differing in lipid level).
- A stylized researcher weighing a fish on a digital scale showing grams.
- Bottom strip with 4 arrowed steps: (1) set up cages and stock 50 fish,
  (2) feed each ration, (3) weigh final weight in grams, (4) compare means with
  ANOVA — small boxplot where feed C is highest.

Short, crisp on-image text, in PORTUGUESE, ONLY these labels:
title "Experimento: 4 rações iso-proteicas para bagres"; "Tanque único";
"4 rações (A, B, C, D)"; "5 réplicas por ração"; "50 peixes por gaiola";
"Pesagem final (g)"; "ANOVA".

Style: scientific editorial design, thin lines, simple icons, soft shadows,
Ocean Gradient palette (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51), clean
sans-serif type. No photorealism, no clutter. Portrait 4:5, high resolution.
Avoid: watermark, gibberish text, logos, busy background, heavy 3D look.
```

---

## Variante B — ilustração editorial semirrealista (mais "cena", menos diagrama)

```
Ilustração editorial semirealista, luz natural de dia, de uma estação de
aquicultura: um grande tanque/viveiro ao ar livre com gaiolas-rede flutuantes
em fileiras, bagres nadando dentro; ao lado, sacos de ração rotulados A, B, C, D
e uma pesquisadora pesando um peixe numa balança. Atmosfera limpa e didática,
paleta em azuis-petróleo e âmbar (Ocean Gradient: #0F3B5F, #2E7D8F, #62B6B7,
#E89B3C, #E76F51). Composição clara, foco no desenho experimental. Pouco ou
nenhum texto. Proporção retrato 4:5, alta resolução. Sem marca d'água.
```

---

## Onde salvar e como inserir no livro (Quarto)

1. Salve a imagem gerada em `eapa/images/` com o nome:
   `experimento_anova_bagres.png` (PNG, fundo branco, ≥ 1500 px de largura).

2. No capítulo `capitulos/capitulo11/anova_estudos_observacionais_experimentais.qmd`,
   na seção **"O experimento: quatro rações iso-proteicas para bagres"**, insira:

```markdown
![Representação do experimento de comparação de quatro rações iso-proteicas para
bagres em delineamento inteiramente casualizado (DIC): um único tanque com
gaiolas-rede, quatro tratamentos (A–D), réplicas e pesagem final que alimenta a
ANOVA. Fonte: elaborado a partir de @bhujel2011 (Tabela 7.4).](../../images/experimento_anova_bagres.png){#fig-experimento width=90%}
```

3. Para referenciar no texto: "...como ilustra a @fig-experimento."

> Observação: o caminho `../../images/` vale porque o capítulo está em
> `capitulos/capitulo11/` e a pasta de imagens é `eapa/images/`.
