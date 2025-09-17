README – viajes activos y En linea / Desconectado
0) Objetivo

Mostrar pedidos con estado “Ride Placed” (ordenados por createdDate DESC).

Sólo listarlos si el conductor está en línea (driverUsers/{uid}.isOnline == true).

Si el conductor está desconectado, mostrar el mensaje desde la carpeta lang/app_es.dart:
"You are Now offline so you can't get nearest order."

Al tocar una card, navegar a una página de detalles.

“Modo desarrollo”: tocar 4 veces el ícono de auto en la card → mostrar ID por 5 segundos.

1) Archivos tocados / agregados


lib/ui/home_screens/new_orders_screen.dart

Pantalla principal (listado de “Ride Placed” + chequeo de isOnline + card con “auto”).

Señales para ubicar:

Stream de pedidos:

FirebaseFirestore.instance.collection(CollectionName.orders)
  .where('status', isEqualTo: Constant.ridePlaced)
  .orderBy('createdDate', descending: true)
  .limit(50)
  .snapshots();


Card con icono de auto:

Positioned(
  top: 6, right: 6,
  child: InkResponse(
    onTap: _onCarTapped,  // 4 taps → muestra ID 5s
    child: Icon(Icons.directions_car, size: 20),
  ),
)


Navegación a detalles:

Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => RidePlacedDetailsPage(order: m)),
);

✅ Agregado 

lib/ui/home_screens/ride_placed_details_page.dart

Pantalla que muestra más datos del pedido.


2) Dependencias y Constantes
Firestore

Colección orders con los datos necesarios para mostrar:

{
  "status": "Ride Placed",
  "createdDate": <Timestamp>,
  "sourceLocationName": "...",
  "destinationLocationName": "...",
  "offerRate": "16.20",
  "distance": "1.11",
  "distanceType": "Km",
  "paymentType": "Cash"
}


Colección driverUsers para poder hacer la funcion en linea y desconectado:

{
  "id": "<uid>",
  "isOnline": true
}


Constant.ridePlaced

se asegura de que su valor string coincida con Firestore:

Constant.ridePlaced == "Ride Placed";

Índice necesario es la consulta

where(status == "Ride Placed")

orderBy(createdDate desc)


3) Traducciones (lang)

Asegúrate de tener en lang/app_es.dart:

'You are Now offline so you can\'t get nearest order.': 'Estás desconectado, por lo tanto, no puedes recibir pedidos cercanos',


La UI usa .tr, así que el texto aparece traducido automáticamente.


4) Cómo funciona (flujo)

La pantalla lee isOnline del conductor (vía coleccion driverUsers/{uid}).

Si isOnline == false → muestra el mensaje traducido y no lista pedidos.

Si isOnline == true → muestra las orders mas recientes filtrando status = Ride Placed y ordenando por createdDate DESC.

Render de cards:

Chips: Tarifa, Distancia, Pago.

Ícono auto (arriba a la derecha): 4 taps → mostrar ID durante 5s.

Tap en la card → abre RidePlacedDetailsPage.