package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func handler(w http.ResponseWriter, r *http.Request) {
	msg := fmt.Sprintf("Hola KCD Bogotá 🚀 - path=%s", r.URL.Path)
	log.Println(msg)
	fmt.Fprintln(w, msg)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	http.HandleFunc("/", handler)
	log.Println("Servidor iniciado en puerto :" + port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
