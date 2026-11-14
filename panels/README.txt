SimLoad Manager - customisable panels
=====================================

ENGLISH

Put your own pictures on the side panels of the SimLoad Manager passenger stairs and apron bus.
The SimLoad Manager pictures shipped in generic/ (panel_*.png) and the templates come back with every update; your
own pictures are never changed or deleted. Give them other names than the panel_*.png shipped files.
To stop using the SimLoad Manager pictures, untick the Random mode or put your pictures in airport/, airline/, country/ or
choose one in the Fixed mode.

Folders (one per vehicle type):
  stairs/   pictures for the passenger stairs, PNG of exactly 2048 x 1024 pixels
  bus/      pictures for the apron bus, PNG of exactly 2048 x 512 pixels
In each of them:
  generic/            "Random" mode: one of these pictures, drawn for each turnaround
  airport/<ICAO>/     "Airport" mode: 4-letter ICAO code of the airport you are at (the nearest), e.g. airport/LFPG/
  airline/<ICAO>/     "Airline" mode: 3-letter ICAO code of the airline of your flight, e.g. airline/AFR/
  country/<ISO>/      "Country" mode: 2-letter ISO code of the country of the airport, e.g. country/FR/
  template.png        template of the type (size and layout); not used as a picture
Any other picture of the type can be chosen in the "Fixed" mode.

Format: PNG only, exact size of the type, 8 bits per channel, RGB or RGBA (sRGB). Pictures are never resized.
A refused picture is listed in Options > Panels with the reason, and in X-Plane's Log.txt.

Options > Panels: for each vehicle type, tick the modes you want and put them in your order with the arrows.
Default order: Airport, Airline, Country, Random. The first mode that finds a picture is used; none: the default panel. Several pictures for a mode: one is drawn
for the turnaround. "Vary pictures": a different picture on each vehicle while there are enough.
After adding or changing pictures, press "Reload".

FRANÇAIS

Mettez vos propres images sur les panneaux latéraux des escaliers passagers et du bus de piste de SimLoad Manager.
Les images SimLoad Manager livrées dans generic/ (panel_*.png) et les gabarits reviennent à chaque mise à jour ;
vos propres images ne sont jamais modifiées ni supprimées. Donnez-leur d'autres noms que les panel_*.png livrés.
Pour ne plus utiliser les images SimLoad Manager, décochez le mode Hasard, ou mettez vos images dans airport/, airline/,
country/, ou choisissez-en une en mode Fixe.

Dossiers (un par type de véhicule) :
  stairs/   images des escaliers passagers, PNG d'exactement 2048 x 1024 pixels
  bus/      images du bus de piste, PNG d'exactement 2048 x 512 pixels
Dans chacun :
  generic/            mode « Hasard » : une de ces images, tirée à chaque escale
  airport/<OACI>/     mode « Aéroport » : code OACI à 4 lettres de l'aéroport où vous êtes (le plus proche), ex. airport/LFPG/
  airline/<OACI>/     mode « Compagnie » : code OACI à 3 lettres de la compagnie du vol, ex. airline/AFR/
  country/<ISO>/      mode « Pays » : code ISO à 2 lettres du pays de l'aéroport, ex. country/FR/
  template.png        gabarit du type (taille et disposition) ; jamais utilisé comme image
Toute autre image du type peut être choisie en mode « Fixe ».

Format : PNG uniquement, taille exacte du type, 8 bits par canal, RGB ou RGBA (sRGB). Les images ne sont jamais
redimensionnées. Une image refusée est listée dans Options > Panels avec la raison, et dans le Log.txt d'X-Plane.

Options > Panels : pour chaque type de véhicule, cochez les modes voulus et classez-les avec les flèches.
Ordre par défaut : Aéroport, Compagnie, Pays, Hasard. Le premier mode qui trouve une image est utilisé ; aucun : le panneau par défaut. Plusieurs images pour un mode :
une est tirée pour l'escale. « Varier les images » : une image différente sur chaque véhicule tant qu'il y en a assez.
Après avoir ajouté ou changé des images, appuyez sur « Recharger ».
