# =========================
# Paleta LabX
# =========================

labx_colors <- list(
  azul = "#1f4e79",
  azul_claro = "#4f81bd",
  azul_muito_claro = "#cfe2f3",
  
  laranja = "#e46c0a",
  laranja_claro = "#f4a261",
  laranja_muito_claro = "#fde3cf",
  
  branco = "#ffffff",
  cinza = "#6c757d"
)

# =========================
# Gradientes monocromáticos
# =========================

pal_mono_azul <- function(n = 5) {
  colorRampPalette(c(
    labx_colors$azul_muito_claro,
    labx_colors$azul
  ))(n)
}

pal_mono_laranja <- function(n = 5) {
  colorRampPalette(c(
    labx_colors$laranja_muito_claro,
    labx_colors$laranja
  ))(n)
}

# =========================
# Gradiente divergente
# =========================

pal_divergente <- function(n = 7) {
  colorRampPalette(c(
    labx_colors$azul,
    labx_colors$branco,
    labx_colors$laranja
  ))(n)
}

# =========================
# Binário (comparação)
# =========================

pal_binaria <- function() {
  c(
    labx_colors$azul,
    labx_colors$laranja
  )
}

# =========================
# ggplot helpers
# =========================

scale_fill_labx_mono_azul <- function(...) {
  ggplot2::scale_fill_gradientn(colors = pal_mono_azul(100), ...)
}

scale_fill_labx_mono_laranja <- function(...) {
  ggplot2::scale_fill_gradientn(colors = pal_mono_laranja(100), ...)
}

scale_fill_labx_divergente <- function(...) {
  ggplot2::scale_fill_gradientn(colors = pal_divergente(100), ...)
}
