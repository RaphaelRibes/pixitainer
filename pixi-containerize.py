import argparse
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--wd", default=".", help="Working directory")
    parser.add_argument("--seamless", action="store_true", help="Enable seamless execution")
    args = parser.parse_args()

    # Utilisation de Path pour la compatibilité Windows/Linux
    wd = Path(args.wd).resolve()
    tmp_dir = Path(".tmp")
    tmp_dir.mkdir(exist_ok=True)

    template_path = Path("pixitainer.def")
    target_path = tmp_dir / "pixitainer.def"

    # Vérification des fichiers requis dans le répertoire de travail
    pixi_toml = wd / "pixi.toml"
    pixi_lock = wd / "pixi.lock"

    if not pixi_toml.exists():
        print(f"Erreur: pixi.toml introuvable dans {wd}")
        sys.exit(1)

    # Préparation de la section %files (Chemins absolus hôte -> Chemins conteneur)
    # On utilise .as_posix() pour s'assurer que les chemins dans le .def utilisent '/' même sur Windows
    files_section = f'    "{pixi_toml.as_posix()}" /app/pixi.toml\n'
    if pixi_lock.exists():
        files_section += f'    "{pixi_lock.as_posix()}" /app/pixi.lock'

    # Logique Seamless
    runscript_content = 'exec pixi run "$@"' if args.seamless else 'exec "$@"'

    if not template_path.exists():
        print("Erreur: pixitainer.def introuvable")
        sys.exit(1)

    # Remplacement et écriture
    content = template_path.read_text()
    content = content.replace("{{ FILES_SECTION }}", files_section)
    content = content.replace("{{ RUNSCRIPT_CONTENT }}", runscript_content)
    target_path.write_text(content)

    # Build (On appelle pixi run apptainer pour utiliser le binaire géré par pixi)
    output_sif = wd / "pixitainer.sif"

    # Correction pour Windows : Apptainer ne tourne pas nativement.
    # Si on est sur Windows, on prévient l'utilisateur.
    if sys.platform == "win32":
        print("⚠️  Note: La préparation des fichiers a réussi, mais Apptainer nécessite WSL ou Linux pour le build.")

    cmd = ["pixi", "run", "apptainer", "build", "--force", "--fakeroot", str(output_sif), str(target_path)]

    print(f"Build en cours (mode seamless: {args.seamless})...")
    subprocess.run(cmd, check=True)
    tmp_dir.rmdir()


if __name__ == "__main__":
    main()