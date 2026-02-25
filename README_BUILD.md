# SimLoadManager - Build & Deploy

## Prerequis

### 1. Installer LuaJIT
Telechargez LuaJIT depuis https://luajit.org/download.html
Extrayez et compilez (ou utilisez un binaire precompile Windows).

### 2. Ajouter LuaJIT au PATH Windows
- Panneau de configuration > Systeme > Variables d'environnement
- Dans "Variables systeme", editez `Path`
- Ajoutez le dossier contenant `luajit.exe`
- Verifiez avec : `luajit -v` dans un terminal

---

## Configuration du chemin X-Plane

Ouvrez `build.bat` et modifiez la variable en haut du fichier :

```bat
set XPLANE_SCRIPTS=C:\X-Plane 12\Resources\plugins\FlyWithLua\Scripts
```

Remplacez par votre chemin reel, par exemple :
```bat
set XPLANE_SCRIPTS=D:\Simulateurs\X-Plane 12\Resources\plugins\FlyWithLua\Scripts
```

---

## Builder le projet

### Methode rapide (VSCode)
`Ctrl+Shift+B` lance automatiquement la tache "Build & Deploy".

### En ligne de commande
```bat
build.bat
```

Le script :
1. Verifie que `luajit` est dans le PATH
2. Compile chaque `.lua` de `src/` vers `dist/` (bytecode LuaJIT)
3. Copie les fichiers compiles vers votre dossier FlyWithLua/Scripts
4. Affiche un message de succes ou d'erreur pour chaque fichier

Apres le build, rechargez les scripts dans X-Plane :
**Plugins > FlyWithLua > Reload all Lua scripts**

---

## Structure du projet

```
src/        Sources Lua - c'est ici que vous editez le code
dist/       Bytecodes compiles - generes automatiquement, ne pas editer
.vscode/    Configuration VSCode (settings, taches)
build.bat   Script de build et deploiement
```

---

## Regles importantes

- **Editez uniquement les fichiers dans `src/`**
- **Ne jamais editer les fichiers dans `dist/`** - ils sont ecrases a chaque build
- **Ne jamais editer les fichiers directement dans le dossier X-Plane** - ils sont ecrases a chaque deploiement
- Le dossier `dist/` est dans `.gitignore` - les bytecodes ne sont pas versiones
