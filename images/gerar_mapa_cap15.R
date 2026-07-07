# =============================================================================
# gerar_mapa_cap15.R
# Gera as 3 figuras do Capítulo 15 (Criação de Mapas em R):
#   images/mapa_aquicultura_2023.png   (coroplético)
#   images/mapa_estacoes_pontos.png    (pontos/estações, nível de publicação)
#   images/mapa_estacoes_bolhas.png    (bolhas proporcionais / CPUE)
#
# Rode UMA vez a partir da raiz do livro (pasta eapa/):
#   source("images/gerar_mapa_cap15.R")
#
# Requer: EAPADados (com aquicultura_br e estacoes_ictiofauna já gerados),
#         geobr, sf, ggplot2, dplyr, ggspatial, ggrepel, cowplot.
# O geobr baixa os limites do IBGE na 1ª vez (internet; depois fica em cache).
# =============================================================================

library(EAPADados)
library(geobr)
library(sf)
library(ggplot2)
library(dplyr)

ocean <- c("#0F3B5F", "#2E7D8F", "#62B6B7", "#E89B3C", "#E76F51")

data(aquicultura_br)
data(estacoes_ictiofauna)

# Geometria dos estados (baixada uma vez)
estados <- read_state(code_state = "all", year = 2020, showProgress = FALSE)
estados4326 <- st_transform(estados, 4326)

# =============================================================================
# 1) COROPLÉTICO — produção aquícola por estado (2023)
# =============================================================================
juntos <- estados |>
  inner_join(filter(aquicultura_br, ano == 2023), by = c("abbrev_state" = "uf"))

juntos$categoria <- cut(juntos$producao_t,
                        breaks = c(0, 5000, 15000, 30000, 100000, Inf),
                        include.lowest = TRUE,
                        labels = c("até 5.000", "5.001 – 15.000", "15.001 – 30.000",
                                   "30.001 – 100.000", "acima de 100.000"))
cores_faixa <- colorRampPalette(c("#DCEBF0", "#9AD1D4", "#62B6B7", "#2E7D8F", "#0F3B5F"))(5)

p_cor <- ggplot(juntos) +
  geom_sf(aes(fill = categoria), color = "white", linewidth = 0.25) +
  scale_fill_manual(values = cores_faixa, name = "Produção (t)") +
  labs(title = "Produção da aquicultura por estado — 2023",
       subtitle = "Faixas de produção (Paraná isolado na faixa mais alta)",
       caption = "Fonte: Revista PEIXE BR · Malha estadual: IBGE via geobr") +
  theme_void(base_size = 13) +
  theme(plot.title = element_text(face = "bold", color = "#0F3B5F", size = 15),
        plot.subtitle = element_text(color = "#495057"),
        plot.caption = element_text(color = "#868e96", size = 8, hjust = 0),
        legend.position = c(0.16, 0.30))
if (requireNamespace("ggspatial", quietly = TRUE)) {
  p_cor <- p_cor +
    ggspatial::annotation_scale(location = "br", height = unit(0.2, "cm")) +
    ggspatial::annotation_north_arrow(location = "tr", width = unit(1, "cm"),
      height = unit(1, "cm"), style = ggspatial::north_arrow_fancy_orienteering())
}
ggsave("images/mapa_aquicultura_2023.png", p_cor, width = 7.2, height = 6.2, dpi = 300, bg = "white")

# =============================================================================
# 2) PONTOS / ESTAÇÕES — nível de publicação (rótulos, grade, escala, inset)
# =============================================================================
pts <- st_as_sf(estacoes_ictiofauna, coords = c("longitude", "latitude"), crs = 4326)
bb  <- st_bbox(pts)
mx  <- as.numeric(bb["xmax"] - bb["xmin"]) * 0.20
my  <- as.numeric(bb["ymax"] - bb["ymin"]) * 0.20
xlim <- c(bb["xmin"] - mx, bb["xmax"] + mx)
ylim <- c(bb["ymin"] - my, bb["ymax"] + my)

p_pontos <- ggplot() +
  geom_sf(data = estados4326, fill = "#EAF0F2", color = "grey75", linewidth = 0.2) +
  geom_sf(data = pts, aes(color = ambiente, shape = ambiente), size = 3.2) +
  scale_color_manual(values = ocean, name = "Ambiente") +
  scale_shape_manual(values = c(16, 17, 15, 18), name = "Ambiente") +
  coord_sf(xlim = xlim, ylim = ylim, expand = FALSE, datum = st_crs(4326)) +
  labs(title = "Estações de coleta de ictiofauna — costa do Pará",
       x = "Longitude", y = "Latitude") +
  theme_bw(base_size = 12) +
  theme(plot.title = element_text(face = "bold", color = "#0F3B5F", size = 14))

if (requireNamespace("ggrepel", quietly = TRUE)) {
  p_pontos <- p_pontos +
    ggrepel::geom_text_repel(data = pts, aes(label = id_estacao, geometry = geometry),
                             stat = "sf_coordinates", size = 3, color = "grey20",
                             min.segment.length = 0, segment.color = "grey60", max.overlaps = 50)
}
if (requireNamespace("ggspatial", quietly = TRUE)) {
  p_pontos <- p_pontos +
    ggspatial::annotation_scale(location = "br", height = unit(0.2, "cm")) +
    ggspatial::annotation_north_arrow(location = "tr", width = unit(1, "cm"),
      height = unit(1, "cm"), style = ggspatial::north_arrow_fancy_orienteering())
}

# Inset de localização (Brasil + retângulo na área de estudo)
p_pontos_final <- p_pontos
if (requireNamespace("cowplot", quietly = TRUE)) {
  inset <- ggplot() +
    geom_sf(data = estados4326, fill = "grey88", color = "white", linewidth = 0.1) +
    annotate("rect", xmin = xlim[1], xmax = xlim[2], ymin = ylim[1], ymax = ylim[2],
             color = "#E76F51", fill = NA, linewidth = 0.7) +
    coord_sf(datum = NA) + theme_void() +
    theme(panel.background = element_rect(fill = "white", color = "grey70"))
  p_pontos_final <- cowplot::ggdraw() +
    cowplot::draw_plot(p_pontos) +
    cowplot::draw_plot(inset, x = 0.015, y = 0.66, width = 0.30, height = 0.30)
}
ggsave("images/mapa_estacoes_pontos.png", p_pontos_final, width = 7.6, height = 6.6, dpi = 300, bg = "white")

# =============================================================================
# 3) BOLHAS PROPORCIONAIS — CPUE por estação
# =============================================================================
p_bolhas <- ggplot() +
  geom_sf(data = estados4326, fill = "#EAF0F2", color = "grey75", linewidth = 0.2) +
  geom_sf(data = pts, aes(size = cpue, color = ambiente), alpha = 0.85) +
  scale_size_area(max_size = 11, name = "CPUE") +
  scale_color_manual(values = ocean, name = "Ambiente") +
  coord_sf(xlim = xlim, ylim = ylim, expand = FALSE, datum = st_crs(4326)) +
  labs(title = "CPUE por estação — costa do Pará",
       x = "Longitude", y = "Latitude") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", color = "#0F3B5F", size = 14))
if (requireNamespace("ggspatial", quietly = TRUE)) {
  p_bolhas <- p_bolhas +
    ggspatial::annotation_scale(location = "br", height = unit(0.2, "cm"))
}
ggsave("images/mapa_estacoes_bolhas.png", p_bolhas, width = 7.6, height = 6.6, dpi = 300, bg = "white")

cat("OK: 3 figuras geradas em images/ (coroplético, pontos, bolhas).\n")
