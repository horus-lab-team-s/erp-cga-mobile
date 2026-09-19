# Application de terrain CGA Broad Range

L'application de l'adhérent : photographier un justificatif dans sa boutique, et le faire
partir quand le réseau revient.

Conception et réalisation : **TCHAMBA TCHAKOUNTE Edwin**, ingénieur informaticien.

## Les cinq dépôts

| Dépôt | Ce qu'il porte |
| --- | --- |
| `erp-cga-backend` | Le serveur, le référentiel légal, le contenu éditorial de la vitrine |
| `erp-cga-console` | La console du cabinet et l'espace de l'adhérent |
| `erp-cga-vitrine` | Le site public |
| **`erp-cga-mobile`** | Ce dépôt : l'application de terrain, hors ligne |
| `erp-cga-plateforme` | La conception, la recette, le déploiement, le site de documentation |

## Ce que cette application est, et ce qu'elle n'est pas

**Elle n'est pas la console en petit.** Le collaborateur du cabinet travaille sur un écran
large, avec un clavier et du réseau ; l'adhérent est dans sa boutique avec une facture en
main. Les deux n'ont pas le même métier, et un produit qui réduit l'un à l'autre rend les
deux mauvais.

Ce qu'elle fait, et qui ne peut se faire ailleurs : **enregistrer une pièce sur l'appareil,
et la faire partir toute seule.** Tout le reste — consulter, corriger, comprendre — s'ouvre
très bien sur le site depuis le même téléphone.

## Démarrer

```bash
flutter pub get
flutter test                                              # 8 cas, la règle de renvoi
flutter run --dart-define=CGA_API=http://10.0.2.2:8010    # émulateur Android
```

⚠️ **`10.0.2.2`, pas `localhost`.** Dans l'émulateur Android, `localhost` désigne
l'émulateur lui-même : l'appel ne sort jamais de l'appareil, et la panne ressemble à un
serveur éteint. Sur un téléphone réel, mettre l'adresse de la machine sur le réseau local.

L'adresse se règle à la compilation et non dans un fichier, pour qu'une version de
démonstration ne puisse pas se retrouver branchée sur la production par un réglage oublié.

Vérifié sur cette machine : `flutter analyze` sans remarque, `flutter test` 8 cas au vert,
`flutter build apk --debug` produit l'APK. Flutter 3.41.4, Dart 3.11.1.

## Comment c'est rangé

| Dossier | Ce qu'il tient |
| --- | --- |
| `lib/domaine/` | Le dépôt, la file et sa règle de renvoi. Aucune dépendance à Flutter ni au réseau |
| `lib/ports/` | Ce dont le domaine a besoin, dit comme un contrat : le magasin durable |
| `lib/adaptateurs/` | Les implémentations de ces contrats |
| `lib/api/` | Le lien avec le serveur |
| `lib/ecrans/` | Ce que l'adhérent voit |

C'est la même séparation que le serveur, pour la même raison : la règle de renvoi est ce
qu'on ne peut pas vérifier à la main — il faudrait couper le réseau au bon moment, vingt
fois de suite. Elle est donc écrite sans rien qui demande un appareil, et éprouvée par des
tests qui s'exécutent en une seconde.

## Les trois règles de la file, et ce qui arrive quand on les oublie

1. **L'ordre est celui de la prise de vue**, pas celui de l'ajout. Une file qui part dans
   le désordre fait arriver la facture du 3 après celle du 17, et le collaborateur qui
   suit le dossier voit une chronologie fausse.

2. **Un refus sort de la file, une indisponibilité y reste.** Confondre les deux donne
   l'un des deux pires défauts possibles : une pièce valable jetée parce que le réseau a
   manqué, ou une file qui ne se vide jamais parce qu'elle insiste contre un serveur qui
   dira toujours non.

3. **La remise est idempotente**, par un identifiant posé sur l'appareil avant le départ.
   Une réponse perdue en route fait rejouer l'envoi ; sans cet identifiant, la même facture
   entrerait deux fois dans la comptabilité de l'adhérent.

## ⚠️ Ce qui n'est pas encore là, dans l'ordre où il doit venir

1. **Le magasin durable.** La file vit aujourd'hui en mémoire : elle ne survit pas à la
   fermeture de l'application. C'est exactement ce que cette application existe pour ne pas
   perdre, et c'est donc le premier chantier. Le port est écrit, l'adaptateur reste à
   faire.
2. **La prise de vue.** Le bouton est en place et désactivé : sa place a été décidée avant,
   pour ne pas être gagnée plus tard sur un écran déjà plein.
3. **Le renvoi en tâche de fond**, réveillé quand le réseau revient.
4. **La session gardée dans le magasin protégé du système.** Elle est pour l'instant en
   mémoire seule : l'adhérent se reconnecte à chaque lancement. L'écrire à moitié vaudrait
   moins que ne pas l'écrire.
5. **L'envoi du fichier lui-même**, en plusieurs morceaux si la connexion est mauvaise.

Tant que le point 1 n'est pas fait, cette application se montre mais ne se met pas entre
les mains d'un adhérent.
