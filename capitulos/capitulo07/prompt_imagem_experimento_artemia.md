# Prompt para gerar a imagem do experimento (Capítulo 7 — Teste t)

Figura: infográfico do experimento de comparação de **duas rações para Artemia
salina** — delineamento inteiramente casualizado (DIC) em laboratório: 7 pequenos
aquários por tratamento (A — farelo de arroz; B — farelo de babaçu), sorteio ao
acaso, medição da taxa de crescimento (mg/dia) → teste t.

> Dica geral: modelos de imagem ainda erram texto. Mantenha **poucos rótulos** e,
> se algum sair torto, gere de novo ou deixe para rotular na diagramação (a legenda
> da figura já carrega a explicação). Peça **proporção retrato 4:5** e alta
> resolução (≥ 1500 px).

---

## Prompt principal — infográfico vetorial (recomendado), em português

```
Infográfico científico em estilo vetorial plano (flat design), limpo e moderno,
fundo branco, para um livro acadêmico de estatística aplicada à aquicultura.
Tema: experimento de laboratório comparando DUAS rações para Artemia salina
(microcrustáceo / alimento vivo), em delineamento inteiramente casualizado.

Composição em vista isométrica suave, numa bancada de laboratório:
- Duas fileiras de pequenos aquários de vidro idênticos, 7 aquários por fileira
  (14 no total). A fileira de cima é a ração A, a de baixo é a ração B.
- Codificar por cor: ração A em verde-petróleo (#2E7D8F), ração B em âmbar
  (#E89B3C). Dentro de cada aquário, pontinhos representando Artemias nadando.
- À esquerda, dois potes de ração rotulados "A" e "B", com ícone de grânulos:
  "A = farelo de arroz", "B = farelo de babaçu".
- Um ícone de sorteio/aleatorização (dado ou setas embaralhando) indicando que os
  aquários foram designados ao acaso.
- À direita, um pequeno medidor/balança de precisão mostrando "mg/dia" e um
  boxplot minúsculo em que a ração A está um pouco mais alta que a B.

Texto curto e nítido, em PORTUGUÊS, apenas estes rótulos:
título "Experimento: 2 rações para Artemia"; "A — farelo de arroz";
"B — farelo de babaçu"; "7 aquários por ração"; "DIC"; "Taxa de crescimento
(mg/dia)"; "Teste t". Nada de texto além desses.

Estilo: design editorial científico, linhas finas, ícones simples, sombras
suaves, paleta Ocean Gradient (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51),
tipografia sem serifa limpa. Sem fotorrealismo, sem excesso de detalhes.
Proporção retrato 4:5, alta resolução.

Evitar: marca d'água, texto ilegível ou inventado, logotipos, fundo poluído,
aparência 3D pesada.
```

---

## Variante em inglês (costuma renderizar o texto com mais precisão)

```
Clean modern flat-design scientific infographic, white background, for an
academic book on statistics applied to aquaculture. Theme: a laboratory
experiment comparing TWO feeds for Artemia salina (tiny live-food crustacean),
in a completely randomized design.

Soft isometric view on a lab bench:
- Two rows of identical small glass aquariums, 7 tanks per row (14 total). Top
  row is feed A, bottom row is feed B.
- Color-code: feed A teal (#2E7D8F), feed B amber (#E89B3C). Tiny dots inside
  each tank represent swimming Artemia.
- On the left, two feed jars labeled "A" and "B" with pellet icons:
  "A = rice bran", "B = babassu bran".
- A randomization icon (a die or shuffling arrows) showing tanks were assigned
  at random.
- On the right, a small precision scale reading "mg/day" and a tiny boxplot where
  feed A sits slightly higher than feed B.

Short, crisp on-image text, in PORTUGUESE, ONLY these labels:
title "Experimento: 2 rações para Artemia"; "A — farelo de arroz";
"B — farelo de babaçu"; "7 aquários por ração"; "DIC"; "Taxa de crescimento
(mg/dia)"; "Teste t".

Style: scientific editorial design, thin lines, simple icons, soft shadows,
Ocean Gradient palette (#0F3B5F, #2E7D8F, #62B6B7, #E89B3C, #E76F51), clean
sans-serif type. No photorealism, no clutter. Portrait 4:5, high resolution.
Avoid: watermark, gibberish text, logos, busy background, heavy 3D look.
```

---

## Onde salvar e como inserir no livro (Quarto)

1. Salve a imagem gerada em `eapa/images/` com o nome:
   `experimento_artemia.png` (PNG, fundo branco, ≥ 1500 px de largura).

2. No capítulo `capitulos/capitulo07/testes_parametricos_uma_duas_amostras.qmd`,
   na seção **"O experimento: duas rações para a Artemia"**, descomente (ou insira)
   a linha:

```markdown
![Desenho do experimento de comparação de duas rações para Artemia em delineamento inteiramente casualizado (DIC): 7 pequenos aquários por tratamento (A — farelo de arroz; B — farelo de babaçu), sorteados ao acaso, com medição da taxa de crescimento (mg/dia).](../../images/experimento_artemia.png){#fig-experimento-artemia width=85%}
```

3. Para referenciar no texto: "...como ilustra a @fig-experimento-artemia."

> Observação: o caminho `../../images/` vale porque o capítulo está em
> `capitulos/capitulo07/` e a pasta de imagens é `eapa/images/`.
