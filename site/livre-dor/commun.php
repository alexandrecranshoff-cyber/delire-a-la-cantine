<?php
// Courrier des lecteurs : lecture et écriture des messages dans donnees/messages.json, sous verrou.

date_default_timezone_set('Europe/Paris');

const LONGUEUR_NOM = 60;
const LONGUEUR_MESSAGE = 2000;
const DELAI_ENTRE_MESSAGES = 60;   // secondes entre deux messages d'une même adresse
const DUREE_MINIMALE_SAISIE = 3;   // secondes : un robot remplit le formulaire plus vite

function reglages(): array
{
    $fichier = __DIR__ . '/config.php';
    if (!is_file($fichier)) {
        $fichier = __DIR__ . '/config.exemple.php';
    }
    $r = require $fichier;
    return $r + ['empreinte_mot_de_passe' => '', 'moderation' => true];
}

function chemin_donnees(): string
{
    return __DIR__ . '/donnees/messages.json';
}

// Lit et modifie un fichier JSON quelconque de donnees/, sous verrou exclusif.
function avec_fichier(string $chemin, callable $modifier)
{
    $f = fopen($chemin, 'c+');
    if ($f === false) {
        throw new RuntimeException('fichier de données inaccessible');
    }
    flock($f, LOCK_EX);
    $contenu = stream_get_contents($f);
    $donnees = $contenu ? json_decode($contenu, true) : null;
    if (!is_array($donnees)) {
        $donnees = [];
    }
    $resultat = $modifier($donnees);
    ftruncate($f, 0);
    rewind($f);
    fwrite($f, json_encode($donnees, JSON_UNESCAPED_UNICODE));
    fflush($f);
    flock($f, LOCK_UN);
    fclose($f);
    return $resultat;
}

function lire_json(string $chemin): array
{
    $contenu = is_file($chemin) ? file_get_contents($chemin) : '';
    $donnees = $contenu ? json_decode($contenu, true) : null;
    return is_array($donnees) ? $donnees : [];
}

// Sel tiré au hasard à la première visite et gardé sur le serveur : les empreintes de visiteurs
// ne peuvent pas être recalculées à partir d'une adresse IP sans lui.
function sel_secret(): string
{
    $chemin = __DIR__ . '/donnees/sel.txt';
    if (!is_file($chemin)) {
        file_put_contents($chemin, bin2hex(random_bytes(32)), LOCK_EX);
    }
    return (string) file_get_contents($chemin);
}

// Ouvre le fichier des messages sous verrou, passe la liste à $modifier, réécrit ce qu'elle renvoie.
function avec_messages(callable $modifier, bool $ecriture)
{
    $f = fopen(chemin_donnees(), 'c+');
    if ($f === false) {
        throw new RuntimeException('fichier des messages inaccessible');
    }
    flock($f, $ecriture ? LOCK_EX : LOCK_SH);
    $contenu = stream_get_contents($f);
    $donnees = $contenu ? json_decode($contenu, true) : null;
    if (!is_array($donnees)) {
        $donnees = ['messages' => [], 'envois' => []];
    }
    $resultat = $modifier($donnees);
    if ($ecriture) {
        ftruncate($f, 0);
        rewind($f);
        fwrite($f, json_encode($donnees, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));
        fflush($f);
    }
    flock($f, LOCK_UN);
    fclose($f);
    return $resultat;
}

function nettoyer(string $texte, int $longueur): string
{
    $texte = str_replace(["\r\n", "\r"], "\n", trim($texte));
    $texte = preg_replace('/[^\P{C}\n]/u', '', $texte) ?? '';
    $texte = preg_replace("/\n{3,}/", "\n\n", $texte) ?? '';
    return mb_substr($texte, 0, $longueur);
}

function repondre(int $code, array $corps): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($corps, JSON_UNESCAPED_UNICODE);
    exit;
}
