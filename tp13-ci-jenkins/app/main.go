// Application de démonstration du TP13 : un micro-serveur HTTP « whoami ».
// C'est le CODE que la chaîne d'intégration (Jenkins) va construire, tester,
// scanner puis publier. Rien de spectaculaire : deux routes suffisent à prouver
// que le pipeline fonctionne de bout en bout.
package main

import (
	"fmt"
	"net/http"
	"os"
)

func main() {
	// /health : sonde utilisée par l'étape « Test » du pipeline (doit répondre « ok »).
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "ok")
	})

	// / : page d'accueil, révèle le nom d'hôte (utile en environnement répliqué).
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host, _ := os.Hostname()
		fmt.Fprintf(w, "Telemach CI — application servie par %s\n", host)
	})

	http.ListenAndServe(":8080", nil)
}
