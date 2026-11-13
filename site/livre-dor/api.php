<?php
// Courrier des lecteurs. GET : messages publiés. POST : nouveau message (nom, message, jeu facultatif).
require __DIR__ . '/commun.php';

$reglages = reglages();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $publies = avec_messages(function (array $d) {
        $liste = array_values(array_filter($d['messages'], fn ($m) => $m['publie']));
        usort($liste, fn ($a, $b) => $b['date'] <=> $a['date']);
        return array_map(fn ($m) => [
            'nom' => $m['nom'], 'message' => $m['message'], 'jeu' => $m['jeu'], 'date' => $m['date'],
        ], array_slice($liste, 0, 100));
    }, false);
    repondre(200, ['messages' => $publies]);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    repondre(405, ['erreur' => 'Méthode non prise en charge.']);
}

// Pièges à robots : champ caché rempli, ou formulaire envoyé trop vite
if (($_POST['site_web'] ?? '') !== '') {
    repondre(200, ['ok' => true, 'moderation' => true]);
}
$ouvert = (int) ($_POST['ouvert'] ?? 0);
if ($ouvert > 0 && time() - intdiv($ouvert, 1000) < DUREE_MINIMALE_SAISIE) {
    repondre(429, ['erreur' => 'Doucement : relis ton message avant de l\'envoyer.']);
}

$nom = nettoyer((string) ($_POST['nom'] ?? ''), LONGUEUR_NOM);
$message = nettoyer((string) ($_POST['message'] ?? ''), LONGUEUR_MESSAGE);
$jeu = in_array($_POST['jeu'] ?? '', ['cantine', 'fric-frac'], true) ? $_POST['jeu'] : '';
if ($nom === '' || mb_strlen($message) < 3) {
    repondre(400, ['erreur' => 'Indique ton nom et écris un message.']);
}
if (preg_match_all('#https?://#i', $message) > 2) {
    repondre(400, ['erreur' => 'Trop de liens dans le message.']);
}

// Adresse gardée seulement sous forme d'empreinte, pour limiter le rythme des envois
$empreinte = hash('sha256', ($_SERVER['REMOTE_ADDR'] ?? '') . __DIR__);
$moderation = (bool) $reglages['moderation'];

$resultat = avec_messages(function (array &$d) use ($empreinte, $nom, $message, $jeu, $moderation) {
    $maintenant = time();
    $d['envois'] = array_filter($d['envois'], fn ($t) => $maintenant - $t < DELAI_ENTRE_MESSAGES);
    if (isset($d['envois'][$empreinte])) {
        return 'trop_tot';
    }
    $d['envois'][$empreinte] = $maintenant;
    $d['messages'][] = [
        'id' => bin2hex(random_bytes(8)),
        'nom' => $nom,
        'message' => $message,
        'jeu' => $jeu,
        'date' => $maintenant,
        'publie' => !$moderation,
    ];
    return 'ok';
}, true);

if ($resultat === 'trop_tot') {
    repondre(429, ['erreur' => 'Un message par minute, pas plus.']);
}
repondre(201, ['ok' => true, 'moderation' => $moderation]);
