<?php

namespace Database\Seeders;

use App\Models\EstadoReclamo;
use App\Models\HistorialEstadoReclamo;
use App\Models\Reclamo;
use App\Models\TipoReclamo;
use App\Models\User;
use App\Models\Voto;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Datos de demostración: una cuenta por rol, vecinos que votan y reclamos
 * repartidos por Comodoro Rivadavia, Rada Tilly y Caleta Córdova.
 *
 * DatabaseSeeder lo ejecuta junto con los datos base; también puede correrse
 * directamente con php artisan db:seed --class=DemoSeeder.
 */
class DemoSeeder extends Seeder
{
    /**
     * Contraseña de todas las cuentas de demostración.
     */
    public const PASSWORD = 'password';

    use WithoutModelEvents;

    public function run(): void
    {
        DB::transaction(function (): void {
            $this->call([EstadoReclamoSeeder::class, TipoReclamoSeeder::class]);

            $operario = $this->crearCuentasPorRol();
            $vecinos = User::whereIn('email', $this->emailsVecinos())->orderBy('email')->get();
            $estados = EstadoReclamo::pluck('id', 'nombre');
            $tipos = TipoReclamo::whereNotNull('icono')->pluck('id', 'icono');

            foreach ($this->reclamos() as $indice => $datos) {
                $creador = $vecinos[$indice % $vecinos->count()];
                $creado = now()->subDays($datos['dias'])->subHours($indice % 7 + 1);

                // Las coordenadas y la dirección identifican cada reclamo del set demo.
                // withTrashed permite restaurarlo si se borró desde la aplicación.
                $reclamo = Reclamo::withTrashed()->firstOrNew([
                    'direccion' => $datos['lugar'],
                    'latitud' => $datos['latitud'],
                    'longitud' => $datos['longitud'],
                ]);
                $reclamo->fill([
                    'usuario_id' => $creador->id,
                    'tipo_reclamo_id' => $tipos[$datos['icono']],
                    'estado_id' => $estados[$datos['estado']],
                    'titulo' => $datos['titulo'],
                    'descripcion' => $datos['descripcion'],
                    'es_publico' => true,
                ]);
                $reclamo->deleted_at = null;
                $reclamo->created_at = $creado;
                $reclamo->updated_at = $creado;
                $reclamo->save();

                // Restablece lo que genera el seeder sin duplicar historial ni votos.
                Voto::where('reclamo_id', $reclamo->id)->delete();
                HistorialEstadoReclamo::where('reclamo_id', $reclamo->id)->delete();
                $this->registrarHistorial($reclamo, $creador, $operario, $estados, $creado);
                $this->votar($reclamo, $creador, $vecinos, $datos['confirman'], $datos['desmienten']);
            }
        });
    }

    /**
     * Crea las cuentas de vecino, operario y admin, y 15 vecinos más que votan.
     * Devuelve el operario, autor de los cambios de estado.
     */
    private function crearCuentasPorRol(): User
    {
        User::updateOrCreate(['email' => 'vecino@sgr.test'], [
            'nombre' => 'Valeria',
            'apellido' => 'Gómez',
            'dni' => '30111222',
            'password' => self::PASSWORD,
            'rol' => 'ciudadano',
            'activo' => true,
        ]);

        $operario = User::updateOrCreate(['email' => 'operario@sgr.test'], [
            'nombre' => 'Martín',
            'apellido' => 'Sosa',
            'dni' => '28444555',
            'rol' => 'empleado',
            'password' => self::PASSWORD,
            'activo' => true,
        ]);

        User::updateOrCreate(['email' => 'admin@sgr.test'], [
            'nombre' => 'Admin',
            'apellido' => 'SGR',
            'rol' => 'admin',
            'password' => self::PASSWORD,
            'activo' => true,
        ]);

        foreach (range(1, 15) as $numero) {
            User::updateOrCreate(['email' => "vecino{$numero}@sgr.test"], [
                'nombre' => "Vecino {$numero}",
                'apellido' => 'Demo',
                'dni' => (string) (35000000 + $numero),
                'rol' => 'ciudadano',
                'password' => self::PASSWORD,
                'activo' => true,
            ]);
        }

        return $operario;
    }

    /** @return list<string> */
    private function emailsVecinos(): array
    {
        return ['vecino@sgr.test', ...array_map(fn (int $numero) => "vecino{$numero}@sgr.test", range(1, 15))];
    }

    /**
     * Registra el estado inicial y, si el reclamo avanzó, los cambios del operario.
     *
     * @param  Collection<string, int>  $estados
     */
    private function registrarHistorial(Reclamo $reclamo, User $creador, User $operario, Collection $estados, Carbon $creado): void
    {
        $cambios = [['pendiente', $creador, null, $creado]];

        if (in_array($reclamo->estado->nombre, ['en_proceso', 'resuelto'], true)) {
            $cambios[] = ['en_proceso', $operario, 'Una cuadrilla ya está trabajando en el lugar.', $creado->copy()->addHours(5)];
        }
        if ($reclamo->estado->nombre === 'resuelto') {
            $cambios[] = ['resuelto', $operario, 'Se reparó el problema y el servicio funciona con normalidad.', $creado->copy()->addDay()];
        }

        foreach ($cambios as [$estado, $autor, $observacion, $fecha]) {
            HistorialEstadoReclamo::create([
                'reclamo_id' => $reclamo->id,
                'estado_id' => $estados[$estado],
                'usuario_id' => $autor->id,
                'observacion' => $observacion,
                'visibilidad' => 'publica',
                'created_at' => $fecha,
            ]);
        }
    }

    /**
     * Votan otros vecinos: el creador nunca vota su propio reclamo.
     *
     * @param  Collection<int, User>  $vecinos
     */
    private function votar(Reclamo $reclamo, User $creador, Collection $vecinos, int $confirman, int $desmienten): void
    {
        $votantes = $vecinos->reject(fn (User $vecino) => $vecino->is($creador))->values();

        foreach ($votantes->take($confirman + $desmienten) as $posicion => $votante) {
            Voto::create([
                'reclamo_id' => $reclamo->id,
                'usuario_id' => $votante->id,
                'valor' => $posicion < $confirman ? 'confirma' : 'desmiente',
            ]);
        }
    }

    /**
     * Reclamos de ejemplo. Las coordenadas son de barrios reales, tomadas de OpenStreetMap.
     *
     * @return list<array{lugar: string, latitud: float, longitud: float, icono: string, estado: string, titulo: ?string, descripcion: string, dias: int, confirman: int, desmienten: int}>
     */
    private function reclamos(): array
    {
        $reclamo = fn (string $lugar, float $latitud, float $longitud, string $icono, string $estado, ?string $titulo, string $descripcion, int $dias, int $confirman = 0, int $desmienten = 0) => compact('lugar', 'latitud', 'longitud', 'icono', 'estado', 'titulo', 'descripcion', 'dias', 'confirman', 'desmienten');

        return [
            // Comodoro Rivadavia: centro y barrios del sur y oeste.
            $reclamo('Centro', -45.8630, -67.4856, 'electricidad', 'pendiente', 'Cable caído en la esquina', 'Hay un cable de luz colgando muy bajo, cerca de la parada del colectivo.', 1, 7),
            $reclamo('Centro', -45.8650, -67.4890, 'agua', 'en_proceso', 'Pérdida de agua en la vereda', 'Sale agua de la vereda hace varios días y se está formando un charco grande.', 3, 4),
            $reclamo('Barrio Roca', -45.8757, -67.5156, 'alumbrado', 'pendiente', 'La cuadra entera sin luminarias', 'Ninguna luminaria de la cuadra prende desde la semana pasada; de noche está muy oscuro.', 6, 2),
            // Corte de luz en Pueyrredón: varios vecinos reclaman lo mismo.
            $reclamo('Barrio Pueyrredón', -45.8829, -67.5160, 'electricidad', 'pendiente', 'Corte de luz en todo el barrio', 'Sin luz desde las 8 de la mañana en varias cuadras.', 0, 12),
            $reclamo('Barrio Pueyrredón', -45.8836, -67.5149, 'electricidad', 'pendiente', null, 'Se cortó la luz en casa y en la de los vecinos.', 0, 3),
            $reclamo('Barrio Pueyrredón', -45.8821, -67.5172, 'electricidad', 'pendiente', null, 'Sin luz. Antes del corte se escuchó una explosión en el transformador.', 0, 2),
            $reclamo('Barrio Pueyrredón', -45.8842, -67.5166, 'electricidad', 'pendiente', null, 'Corte de luz.', 0),
            $reclamo('Barrio Pueyrredón', -45.8818, -67.5153, 'electricidad', 'pendiente', 'Transformador quemado', 'Sale humo del transformador de la esquina.', 0, 5),
            $reclamo('Barrio Juan XXIII', -45.8754, -67.5356, 'cloacas', 'pendiente', 'Desborde de cloaca en la calle', 'La cloaca desborda y el agua corre por la calle; hay mucho olor.', 2, 3, 1),
            $reclamo('Barrio San Cayetano', -45.8671, -67.5432, 'agua', 'en_proceso', 'Sin agua hace dos días', 'No sale agua de las canillas desde el martes.', 2, 9),
            $reclamo('Barrio Ceferino Namuncurá', -45.8625, -67.5139, 'telefonia', 'pendiente', 'Sin internet en el barrio', 'Varias casas sin servicio de internet desde ayer.', 1, 1),
            $reclamo('Barrio Jorge Newbery', -45.8604, -67.5045, 'alumbrado', 'pendiente', null, 'Luminaria apagada frente a la plaza.', 4),
            $reclamo('Barrio Stella Maris', -45.8903, -67.5127, 'agua', 'pendiente', 'Baja presión de agua', 'A la tarde el agua sale con muy poca presión.', 3, 1, 2),
            $reclamo('Zona Franca Industrial', -45.9047, -67.5871, 'electricidad', 'en_proceso', 'Baja tensión en la zona industrial', 'Las máquinas se apagan por la baja tensión.', 3, 2),
            // Comodoro Rivadavia: zona norte.
            $reclamo('Barrio Saavedra', -45.8419, -67.5075, 'cloacas', 'en_proceso', 'Tapa de cloaca rota', 'La tapa de la cámara está rota y es peligrosa para los autos.', 5, 2),
            $reclamo('Barrio Laprida', -45.8287, -67.5417, 'electricidad', 'pendiente', 'Poste inclinado', 'Un poste de luz quedó inclinado después del viento y parece que se va a caer.', 1, 5),
            $reclamo('Km 3', -45.8388, -67.4760, 'alumbrado', 'resuelto', 'Luminaria intermitente', 'La luminaria de la esquina se prende y se apaga toda la noche.', 9, 1),
            $reclamo('Km 5 - Barrio Castelli', -45.8164, -67.4727, 'agua', 'resuelto', 'Caño roto en la vereda', 'Se rompió un caño y sale mucha agua.', 12, 3),
            $reclamo('Km 5 - Presidente Ortiz', -45.8114, -67.4500, 'electricidad', 'pendiente', 'Transformador con chispas', 'El transformador hace ruido y tira chispas cuando hay viento.', 2, 3),
            $reclamo('Km 8 - Don Bosco', -45.7956, -67.4231, 'cloacas', 'pendiente', null, 'Olor fuerte a cloaca en toda la cuadra.', 4, 1),
            $reclamo('Diadema Argentina', -45.7798, -67.6719, 'telefonia', 'en_proceso', 'Sin teléfono fijo', 'El teléfono fijo no tiene tono desde hace una semana.', 7),
            // Rada Tilly.
            $reclamo('Rada Tilly', -45.9239, -67.5620, 'agua', 'pendiente', 'Pérdida de agua cerca de la costanera', 'Hay una pérdida de agua importante sobre la calle.', 2, 4),
            $reclamo('Rada Tilly', -45.9285, -67.5650, 'alumbrado', 'resuelto', 'Calle a oscuras', 'Las luminarias de la calle no funcionan.', 10, 2),
            // Caleta Córdova.
            $reclamo('Caleta Córdova', -45.7489, -67.3860, 'electricidad', 'pendiente', 'Cortes de luz intermitentes', 'La luz se corta varias veces por día.', 1, 6),
            $reclamo('Caleta Córdova', -45.7470, -67.3880, 'agua', 'en_proceso', null, 'No llega agua a las casas de la parte alta.', 3, 1),
        ];
    }
}
