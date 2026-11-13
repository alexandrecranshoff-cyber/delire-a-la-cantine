<?php
// Courrier des lecteurs : publier ou supprimer les messages. Mot de passe dans config.php (empreinte).
require __DIR__ . '/commun.php';

session_set_cookie_params(['httponly' => true, 'samesite' => 'Strict', 'secure' => !empty($_SERVER['HTTPS'])]);
session_start();
header('Content-Type: text/html; charset=utf-8');
header('X-Frame-Options: DENY');

$reglages = reglages();
$empreinte = (string) $reglages['empreinte_mot_de_passe'];
$erreur = '';

if ($empreinte === '') {
    $erreur = 'Administration désactivée : aucun mot de passe configuré (secret LIVRE_DOR_MOT_DE_PASSE).';
} elseif (isset($_POST['mot_de_passe'])) {
    usleep(400000); // freine les essais en série
    if (password_verify((string) $_POST['mot_de_passe'], $empreinte)) {
        session_regenerate_id(true);
        $_SESSION['admin'] = true;
        $_SESSION['jeton'] = bin2hex(random_bytes(16));
        header('Location: admin.php');
        exit;
    }
    $erreur = 'Mot de passe incorrect.';
}

$connecte = $empreinte !== '' && !empty($_SESSION['admin']);

if ($connecte && isset($_POST['action'], $_POST['id'])) {
    if (!hash_equals($_SESSION['jeton'] ?? '', (string) ($_POST['jeton'] ?? ''))) {
        http_response_code(400);
        exit('Jeton invalide, recharge la page.');
    }
    $id = (string) $_POST['id'];
    $action = (string) $_POST['action'];
    avec_messages(function (array &$d) use ($id, $action) {
        foreach ($d['messages'] as $i => $m) {
            if ($m['id'] !== $id) {
                continue;
            }
            if ($action === 'supprimer') {
                array_splice($d['messages'], $i, 1);
            } else {
                $d['messages'][$i]['publie'] = $action === 'publier';
            }
            break;
        }
    }, true);
    header('Location: admin.php');
    exit;
}
if ($connecte && isset($_POST['deconnexion'])) {
    session_destroy();
    header('Location: admin.php');
    exit;
}

$vue = ($_GET['vue'] ?? '') === 'audience' ? 'audience' : 'courrier';
$messages = $connecte ? avec_messages(fn (array $d) => $d['messages'], false) : [];

// Audience des 30 derniers jours, lue dans les fichiers du mois courant et du précédent
$jours = [];
$totaux = ['pages' => [], 'sources' => [], 'appareils' => [], 'clics' => []];
if ($connecte && $vue === 'audience') {
    $donnees = lire_json(__DIR__ . '/donnees/audience-' . date('Y-m', strtotime('first day of last month')) . '.json')
        + lire_json(__DIR__ . '/donnees/audience-' . date('Y-m') . '.json');
    for ($i = 29; $i >= 0; $i--) {
        $jour = date('Y-m-d', strtotime("-$i days"));
        $j = $donnees[$jour] ?? [];
        $jours[$jour] = ['vues' => $j['vues'] ?? 0, 'visiteurs' => count($j['visiteurs'] ?? [])];
        foreach ($totaux as $cle => $_) {
            foreach ($j[$cle] ?? [] as $nom => $n) {
                $totaux[$cle][$nom] = ($totaux[$cle][$nom] ?? 0) + $n;
            }
        }
    }
    foreach ($totaux as &$liste) {
        arsort($liste);
    }
    unset($liste);
}
usort($messages, fn ($a, $b) => [$a['publie'], -$a['date']] <=> [$b['publie'], -$b['date']]);
$h = fn ($t) => htmlspecialchars((string) $t, ENT_QUOTES, 'UTF-8');
$jeux = ['cantine' => 'Délire à la cantine', 'fric-frac' => 'Fric-Frac'];
?>
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Administration iomino.fr</title>
<style>
:root { --encre: #16130f; --papier: #f3ecdd; --clair: #fbf7ee; --rouge: #c8242b; --gris: #6c6458; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--papier); color: var(--encre); font: 1.05rem/1.5 Georgia, serif; padding: 24px max(16px, 4vw); }
h1 { font-size: 1.9rem; margin: 0 0 18px; }
.erreur { color: var(--rouge); }
.carte { background: var(--clair); border: 1px solid rgba(22,19,15,.3); padding: 14px 18px; margin-bottom: 14px; max-width: 760px; }
.carte.attente { border-left: 5px solid var(--rouge); }
.meta { color: var(--gris); font-size: .92rem; margin-bottom: 6px; }
.texte { white-space: pre-wrap; margin: 0 0 10px; }
nav { display: flex; gap: 18px; margin: -6px 0 22px; }
nav a { color: var(--encre); }
nav a.actif { color: var(--rouge); font-weight: bold; text-decoration: none; }
.chiffres { display: flex; gap: 14px; flex-wrap: wrap; margin-bottom: 22px; }
.chiffres div { background: var(--clair); border: 1px solid rgba(22,19,15,.3); padding: 10px 16px; min-width: 150px; }
.chiffres b { display: block; font-size: 1.8rem; font-variant-numeric: tabular-nums; }
.courbe { display: grid; grid-template-columns: repeat(30, 1fr); gap: 3px; align-items: end; height: 160px; max-width: 760px; border-bottom: 1px solid var(--encre); margin-bottom: 4px; }
.courbe span { background: var(--encre); position: relative; min-height: 1px; }
.courbe span i { position: absolute; inset: auto 0 0 0; background: var(--rouge); }
.axe { display: flex; justify-content: space-between; max-width: 760px; color: var(--gris); font-size: .85rem; margin-bottom: 24px; }
.listes { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 18px; max-width: 980px; }
table { border-collapse: collapse; width: 100%; font-size: .98rem; }
td { padding: 3px 0; border-bottom: 1px dotted rgba(22,19,15,.3); }
td:last-child { text-align: right; font-variant-numeric: tabular-nums; }
h2 { font-size: 1.2rem; margin: 0 0 6px; }
.legende-courbe { color: var(--gris); font-size: .9rem; margin: 0 0 8px; }
.legende-courbe i { display: inline-block; width: 10px; height: 10px; vertical-align: 0; margin: 0 4px 0 10px; }
form.inline { display: inline; }
button { font: inherit; padding: 4px 14px; border: 1px solid var(--encre); background: #fff; cursor: pointer; }
button.publier { background: var(--encre); color: #fff; }
input[type=password] { font: inherit; padding: 6px 10px; }
</style>
</head>
<body>
<h1>iomino.fr, administration</h1>
<?php if ($erreur): ?><p class="erreur"><?= $h($erreur) ?></p><?php endif; ?>
<?php if (!$connecte && $empreinte !== ''): ?>
  <form method="post"><label>Mot de passe <input type="password" name="mot_de_passe" autofocus required></label> <button>Entrer</button></form>
<?php elseif ($connecte): ?>
  <nav><a href="admin.php" class="<?= $vue === 'courrier' ? 'actif' : '' ?>">Courrier</a><a href="admin.php?vue=audience" class="<?= $vue === 'audience' ? 'actif' : '' ?>">Audience</a></nav>
<?php endif; ?>
<?php if ($connecte && $vue === 'audience'): ?>
  <?php
    $max = max(1, ...array_column($jours, 'vues'));
    $somme = fn (string $c) => array_sum(array_column($jours, $c));
    $nomsPages = ['/' => 'Accueil', '/delire-a-la-cantine.html' => 'Délire à la cantine', '/fric-frac.html' => 'Fric-Frac'];
    $nomsClics = ['jeu:cantine' => 'Jouer à la cantine (navigateur)', 'telechargement:delire_a_la_cantine_pc_windows.zip' => 'Cantine, Windows', 'telechargement:delire_a_la_cantine_pc_linux.zip' => 'Cantine, Linux'];
    $tableau = function (array $liste, array $noms = []) use ($h) {
        if (!$liste) { return '<p class="legende-courbe">Rien pour l\'instant.</p>'; }
        $lignes = '';
        foreach (array_slice($liste, 0, 12, true) as $nom => $n) {
            $lignes .= '<tr><td>' . $h($noms[$nom] ?? $nom) . '</td><td>' . (int) $n . '</td></tr>';
        }
        return '<table>' . $lignes . '</table>';
    };
  ?>
  <div class="chiffres">
    <div><b><?= $somme('visiteurs') ?></b>visiteurs (30 jours)</div>
    <div><b><?= $somme('vues') ?></b>pages vues</div>
    <div><b><?= $jours[date('Y-m-d')]['visiteurs'] ?></b>visiteurs aujourd'hui</div>
    <div><b><?= array_sum(array_filter($totaux['clics'], fn ($k) => str_starts_with($k, 'telechargement:'), ARRAY_FILTER_USE_KEY)) ?></b>téléchargements</div>
  </div>
  <p class="legende-courbe">Par jour :<i style="background:var(--encre)"></i>pages vues<i style="background:var(--rouge)"></i>visiteurs</p>
  <div class="courbe">
    <?php foreach ($jours as $jour => $j): ?>
      <span style="height:<?= round($j['vues'] / $max * 100, 1) ?>%" title="<?= $h(date('d/m', strtotime($jour))) ?> : <?= $j['vues'] ?> pages vues, <?= $j['visiteurs'] ?> visiteurs"><i style="height:<?= $j['vues'] ? round($j['visiteurs'] / $j['vues'] * 100, 1) : 0 ?>%"></i></span>
    <?php endforeach; ?>
  </div>
  <div class="axe"><span><?= date('d/m', strtotime('-29 days')) ?></span><span><?= date('d/m') ?></span></div>
  <div class="listes">
    <div><h2>Pages</h2><?= $tableau($totaux['pages'], $nomsPages) ?></div>
    <div><h2>Venus de</h2><?= $tableau($totaux['sources']) ?></div>
    <div><h2>Jeux lancés et téléchargés</h2><?= $tableau($totaux['clics'], $nomsClics) ?></div>
    <div><h2>Appareils</h2><?= $tableau($totaux['appareils']) ?></div>
  </div>
  <p class="legende-courbe" style="margin-top:22px">Mesure sans cookie : l'adresse IP n'est jamais gardée, et les visiteurs qui demandent à ne pas être suivis ne sont pas comptés.</p>
<?php elseif ($connecte): ?>
  <p><?= count(array_filter($messages, fn ($m) => !$m['publie'])) ?> message(s) en attente · <?= count($messages) ?> au total ·
    <form class="inline" method="post"><button name="deconnexion" value="1">Se déconnecter</button></form></p>
  <?php if (!$messages): ?><p>Aucun message pour l'instant.</p><?php endif; ?>
  <?php foreach ($messages as $m): ?>
    <div class="carte <?= $m['publie'] ? '' : 'attente' ?>">
      <div class="meta"><b><?= $h($m['nom']) ?></b> · <?= $h(date('d/m/Y H:i', $m['date'])) ?><?= $m['jeu'] ? ' · ' . $h($jeux[$m['jeu']] ?? '') : '' ?> · <?= $m['publie'] ? 'publié' : 'en attente' ?></div>
      <p class="texte"><?= $h($m['message']) ?></p>
      <?php foreach ($m['publie'] ? ['masquer' => 'Masquer'] : ['publier' => 'Publier'] as $a => $libelle): ?>
        <form class="inline" method="post"><input type="hidden" name="jeton" value="<?= $h($_SESSION['jeton']) ?>"><input type="hidden" name="id" value="<?= $h($m['id']) ?>"><button class="<?= $a ?>" name="action" value="<?= $a ?>"><?= $libelle ?></button></form>
      <?php endforeach; ?>
      <form class="inline" method="post"><input type="hidden" name="jeton" value="<?= $h($_SESSION['jeton']) ?>"><input type="hidden" name="id" value="<?= $h($m['id']) ?>"><button name="action" value="supprimer">Supprimer</button></form>
    </div>
  <?php endforeach; ?>
<?php endif; ?>
</body>
</html>
