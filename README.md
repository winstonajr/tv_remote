# Órbita — controle remoto para TV box (Flutter)

Fala o protocolo Android TV Remote v2 (o mesmo do app oficial do Google TV):
portas 6467 (pareamento) e 6466 (controle). Não precisa de ADB nem de opções
de desenvolvedor. Na primeira conexão a TV mostra um código de 6 caracteres.

## Gerar o APK
    ./build.sh

## Testar só a interface
    flutter run --dart-define=DEMO=true
