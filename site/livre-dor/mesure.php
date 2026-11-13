<?php
// Mesure d'audience sans cookie : une ligne par page vue ou par clic utile (téléchargement, lancement du jeu).
// Rien n'identifie un visiteur : l'adresse IP n'est jamais gardée, seulement une empreinte du jour,
// qui change chaque nuit et ne sert qu'à compter les visiteurs uniques de la journée.
require __DIR__ . '/commun.php';

header('Cache-Control: no-store');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    exit;
}
$agent = (string) ($_SERVER['HTTP_USER_AGENT'] ?? '');
if ($agent === '' || preg_match('/bot|crawl|spider|slurp|preview|monitor|headless|lighthouse|curl|wget|python/i', $agent)) {
    http_response_code(204);
    exit;
}

$evenement = in_array($_POST['e'] ?? '', ['vue', 'telechargement', 'jeu'], true) ? $_POST['e'] : 'vue';
$page = '/' . ltrim(preg_replace('#[^a-z0-9/._-]#i', '', (string) ($_POST['p'] ?? '/')) ?? '', '/');
$page = mb_substr($page === '/index.html' ? '/' : $page, 0, 80);
$cible = mb_substr(preg_replace('#[^a-z0-9._-]#i', '', (string) ($_POST['c'] ?? '')) ?? '', 0, 60);

// Provenance : seulement le nom du site d'où l'on vient, hors iomino.fr
$source = '';
$hote = parse_url((string) ($_POST['r'] ?? ''), PHP_URL_HOST);
if (is_string($hote) && $hote !== '') {
    $hote = preg_replace('/^www\./', '', strtolower($hote));
    if ($hote !== 'iomino.fr' && $hote !== strtolower($_SERVER['HTTP_HOST'] ?? '')) {
        $source = mb_substr($hote, 0, 60);
    }
}
$appareil = preg_match('/Mobi|Android|iPhone|iPad/i', $agent) ? 'mobile' : 'ordinateur';

$jour = date('Y-m-d');
$visiteur = substr(hash('sha256', sel_secret() . $jour . ($_SERVER['REMOTE_ADDR'] ?? '') . $agent), 0, 16);

avec_fichier(__DIR__ . '/donnees/audience-' . date('Y-m') . '.json', function (array &$d) use ($jour, $visiteur, $evenement, $page, $cible, $source, $appareil) {
    $j = $d[$jour] ?? ['vues' => 0, 'visiteurs' => [], 'pages' => [], 'sources' => [], 'appareils' => [], 'clics' => []];
    if ($evenement === 'vue') {
        $j['vues']++;
        $nouveau = !isset($j['visiteurs'][$visiteur]);
        $j['visiteurs'][$visiteur] = 1;
        $j['pages'][$page] = ($j['pages'][$page] ?? 0) + 1;
        if ($source !== '') {
            $j['sources'][$source] = ($j['sources'][$source] ?? 0) + 1;
        }
        if ($nouveau) {
            $j['appareils'][$appareil] = ($j['appareils'][$appareil] ?? 0) + 1;
        }
    } else {
        $cle = $evenement . ':' . ($cible ?: '?');
        $j['clics'][$cle] = ($j['clics'][$cle] ?? 0) + 1;
    }
    $d[$jour] = $j;
});
http_response_code(204);
