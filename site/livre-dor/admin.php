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

$messages = $connecte ? avec_messages(fn (array $d) => $d['messages'], false) : [];
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
<title>Courrier des lecteurs, administration</title>
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
form.inline { display: inline; }
button { font: inherit; padding: 4px 14px; border: 1px solid var(--encre); background: #fff; cursor: pointer; }
button.publier { background: var(--encre); color: #fff; }
input[type=password] { font: inherit; padding: 6px 10px; }
</style>
</head>
<body>
<h1>Courrier des lecteurs</h1>
<?php if ($erreur): ?><p class="erreur"><?= $h($erreur) ?></p><?php endif; ?>
<?php if (!$connecte && $empreinte !== ''): ?>
  <form method="post"><label>Mot de passe <input type="password" name="mot_de_passe" autofocus required></label> <button>Entrer</button></form>
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
