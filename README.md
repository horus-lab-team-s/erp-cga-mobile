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
flutter test                                              # 33 cas : renvoi, durabilité, prise de vue
flutter run --dart-define=CGA_API=http://10.0.2.2:8010    # émulateur Android
```

⚠️ **`10.0.2.2`, pas `localhost`.** Dans l'émulateur Android, `localhost` désigne
l'émulateur lui-même : l'appel ne sort jamais de l'appareil, et la panne ressemble à un
serveur éteint. Sur un téléphone réel, mettre l'adresse de la machine sur le réseau local.

L'adresse se règle à la compilation et non dans un fichier, pour qu'une version de
démonstration ne puisse pas se retrouver branchée sur la production par un réglage oublié.

Vérifié sur cette machine : `flutter analyze --fatal-infos` sans remarque, 33 cas au vert,
`flutter build apk --debug` produit l'APK. Flutter 3.41.4, Dart 3.11.1.

## Comment c'est rangé

| Dossier | Ce qu'il tient |
| --- | --- |
| `lib/domaine/` | Le dépôt, la file et sa règle de renvoi. Aucune dépendance à Flutter ni au réseau |
| `lib/ports/` | Ce dont le domaine a besoin, dit comme un contrat : le magasin durable, l'appareil photo |
| `lib/adaptateurs/` | Les implémentations de ces contrats : la file écrite sur l'appareil |
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

## La remise, et pourquoi elle est rejouable

Le serveur prend la pièce en **deux temps** : les octets d'abord, la pièce ensuite, qui
cite l'empreinte que le serveur a calculée dessus et qu'il **revérifie** en relisant le
fichier.

⚠️ **L'idempotence vient de là, et non de l'identifiant de l'appareil.** Ce dépôt affirmait
le contraire dans sa première version. Confronté au code du serveur, c'était faux, et la
vérité est meilleure : deux envois des mêmes octets sur le même dossier produisent la même
empreinte, donc la même clé de pièce, et le second rend la pièce **inchangée** en 200 avec
`rejeu: true`. La propriété ne dépend donc pas d'un numéro que le client pourrait se
tromper de recopier.

La traduction des codes est écrite une seule fois, dans `sortDuCode` :

| Réponse du serveur | Sort du dépôt |
| --- | --- |
| 201, 200 (rejeu) | part, et sort de la file |
| 401 | **se reconnecter** — la pièce reste en attente, sans tentative comptée |
| 403, 404, 409, 413, 415, 422 | refusé : rien ne changera avec le temps |
| 5xx, 429, imprévu, pas de réseau | on réessaiera |

⚠️ Le 401 a été ajouté après coup, et son absence coûtait cher. Il tombait dans « refusé »,
faute de mieux : un adhérent qui avait laissé l'application quelques jours retrouvait au
retour **toutes ses pièces déclarées irrécupérables**. Rien n'était refusé, personne n'avait
demandé.

## Vérifier contre un vrai serveur

Les cas d'essai ne touchent jamais au réseau. Ils ne peuvent donc pas dire si l'enveloppe
multipart, écrite à la main, est correcte — et c'est là que ça se joue : un `\r\n` manquant
avant la séparation finale fait lire au serveur deux octets de trop, l'empreinte change à
chaque envoi, et l'idempotence disparaît sans le moindre message.

```bash
cd ../erp-cga-backend && outils/pile-de-demonstration.sh neuve
cd ../erp-cga-mobile  && dart run outils/remise_reelle.dart
```

L'outil envoie une pièce, la renvoie, et vérifie que le serveur répond « rejeu ». Puis il
ferme la session et vérifie que la file s'arrête sans condamner la pièce.

## La prise de vue, et la copie qui la sauve

L'appareil photo du système range son résultat dans un **cache**. Le système vide les caches
quand la place manque, sans prévenir et sans demander.

⚠️ **Si la file gardait ce chemin-là**, voici ce qui arriverait : l'adhérent photographie six
factures un samedi, sans réseau ; le téléphone se remplit ; le lundi, la file tente ses six
remises et ne trouve plus aucun fichier. Les six dépôts sortent de la file comme **refusés**.
Le pire n'est pas la perte : c'est qu'elle ressemble à un refus du cabinet.

Les octets sont donc recopiés à côté de la file, dans le dossier des documents, que le
système ne reprend jamais. Et la copie s'efface **après** la remise, jamais avant : effacée
plus tôt, elle perdrait la pièce si la réponse se perdait en route. Une pièce **refusée**
garde sa copie, pour que l'adhérent puisse regarder ce que le cabinet n'a pas pris.

L'image est réduite à 2 000 pixels de large, qualité 85. Ce n'est pas une optimisation : un
téléphone récent produit des images de plusieurs dizaines de mégaoctets, le serveur refuse
au-delà de vingt, et ce refus se traduit en « rien ne changera ». L'adhérent verrait ses
factures rejetées sans comprendre, alors que le cabinet n'a rien refusé.

## ⚠️ Ce qui n'est pas encore là, dans l'ordre où il doit venir

1. **Le renvoi en tâche de fond**, réveillé quand le réseau revient. L'envoi se déclenche
   aujourd'hui à la main, depuis l'accueil.
2. **La session gardée dans le magasin protégé du système.** Elle est pour l'instant en
   mémoire seule : l'adhérent se reconnecte à chaque lancement. L'écrire à moitié vaudrait
   moins que ne pas l'écrire.
3. **L'envoi en plusieurs morceaux** si la connexion est mauvaise. Le fichier part
   aujourd'hui d'un bloc, et une coupure au milieu fait tout recommencer.

## ⚠️ Ce qui n'a jamais tourné sur un vrai téléphone

**Aucun appareil Android ou iOS n'a exécuté cette application.** Il n'y en a pas sur la
machine où elle est écrite. Ce qui est donc vérifié, et ce qui ne l'est pas :

| Vérifié | Comment |
| --- | --- |
| La règle de renvoi, la durabilité, la recopie | 33 cas, avec une source d'images feinte |
| Le protocole, l'enveloppe multipart, le rejeu | `outils/remise_reelle.dart` contre le serveur réel |
| Que le projet compile et s'assemble | `flutter build apk` |

| **Non vérifié** | Ce qu'il faudra regarder au premier essai sur un appareil |
| --- | --- |
| L'appareil photo lui-même | `AppareilPhotoDuSysteme` fait quinze lignes et appelle l'appareil du système. Il n'a jamais été exécuté |
| L'autorisation d'accès à l'appareil photo | Android la demande à l'usage ; rien ne prouve ici que le dialogue s'affiche |
| L'orientation de l'image | Une photo prise en paysage peut arriver tournée. Cela se voit à l'œil, et seulement sur un appareil |
| Le dossier des documents | Son chemin réel dépend du système. Les cas d'essai emploient un dossier temporaire |
