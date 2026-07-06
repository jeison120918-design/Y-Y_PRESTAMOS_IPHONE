#!/usr/bin/env bash
# ============================================================================
# Deploy de Y&Y Prestamos (Flutter Web) a GitHub Pages
# ============================================================================
# Soluciona los 4 motivos más comunes del error 404 en GitHub Pages:
#   1. --base-href incorrecto (assets pidiendo rutas equivocadas)
#   2. Rama/carpeta mal configurada en Settings > Pages
#   3. index.html empujado dentro de una subcarpeta build/web en vez de la raíz
#   4. Jekyll (procesador por defecto de GitHub Pages) ignorando archivos
#      -> se soluciona con un archivo .nojekyll en la raíz de la rama
#
# USO:
#   ./deploy_github_pages.sh <usuario-github> <nombre-repo>
#
# Ejemplo (si tu repo es github.com/juanperez/yy-prestamos):
#   ./deploy_github_pages.sh juanperez yy-prestamos
#
# Requisitos: tener Flutter instalado, el repo ya creado en GitHub, y el
# remoto "origin" ya configurado (git remote -v debe mostrar tu repo).
# ============================================================================

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Uso: $0 <usuario-github> <nombre-repo>"
  echo "Ejemplo: $0 juanperez yy-prestamos"
  exit 1
fi

GH_USER="$1"
REPO_NAME="$2"

# Repositorio de usuario/organización: https://usuario.github.io/
# Repositorio de proyecto:         https://usuario.github.io/repo/
if [ "$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]')" = "$(echo "${GH_USER}.github.io" | tr '[:upper:]' '[:lower:]')" ]; then
  BASE_HREF="/"
else
  BASE_HREF="/${REPO_NAME}/"
fi

echo ">> Compilando Flutter Web con base-href = ${BASE_HREF}"
flutter pub get
flutter build web --release --base-href "${BASE_HREF}"

echo ">> Asegurando .nojekyll en la salida"
touch build/web/.nojekyll

echo ">> Generando 404.html para refrescos / rutas de GitHub Pages"
cp build/web/index.html build/web/404.html

echo ">> Verificando que index.html exista en build/web (raíz)"
if [ ! -f "build/web/index.html" ]; then
  echo "ERROR: build/web/index.html no existe. Revisa que 'flutter build web' haya terminado sin errores."
  exit 1
fi

echo ">> Publicando la carpeta build/web en la rama gh-pages (en la RAÍZ de la rama, no en una subcarpeta)"
# Usamos git subtree-like manual push: creamos un commit huérfano solo con
# el contenido de build/web y lo forzamos a la rama gh-pages.
TMP_DIR=$(mktemp -d)
cp -r build/web/. "${TMP_DIR}/"

pushd "${TMP_DIR}" > /dev/null
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.name="github-pages-deploy" -c user.email="actions@users.noreply.github.com" \
  commit -q -m "Deploy Y&Y Prestamos Web ($(date '+%Y-%m-%d %H:%M'))"
git remote add origin "https://github.com/${GH_USER}/${REPO_NAME}.git"
git push -f origin gh-pages
popd > /dev/null

rm -rf "${TMP_DIR}"

echo ""
echo "============================================================"
echo "Listo. Ahora en GitHub:"
echo "  1. Ve a: https://github.com/${GH_USER}/${REPO_NAME}/settings/pages"
echo "  2. En 'Build and deployment' -> Source: 'Deploy from a branch'"
echo "  3. Branch: gh-pages   /  Folder: / (root)"
echo "  4. Guarda. Espera 1-2 minutos."
if [ "${BASE_HREF}" = "/" ]; then
  echo "  5. Abre: https://${GH_USER}.github.io/"
else
  echo "  5. Abre: https://${GH_USER}.github.io/${REPO_NAME}/"
fi
echo "============================================================"
