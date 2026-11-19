<?php

namespace Tests\Feature;

use App\Models\EstadoReclamo;
use App\Models\Reclamo;
use App\Models\TipoReclamo;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReclamoEdicionYBajaTest extends TestCase
{
    use RefreshDatabase;

    public function test_ciudadano_puede_editar_su_reclamo_pendiente(): void
    {
        $this->mockearApisExternas();

        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'pendiente');

        Sanctum::actingAs($vecino);

        $response = $this->putJson("/api/reclamos/{$reclamo->id}", [
            'titulo' => 'Luminaria caída en esquina',
            'descripcion' => 'El poste está inclinado y sin luz.',
            'latitud' => -45.9250000,
            'longitud' => -67.5510000,
            // Intentamos enviar campos no permitidos para verificar que se ignoren
            'usuario_id' => 999,
            'estado_id' => 3,
        ]);

        $response->assertOk()
            ->assertJsonPath('data.titulo', 'Luminaria caída en esquina')
            ->assertJsonPath('data.descripcion', 'El poste está inclinado y sin luz.')
            ->assertJsonPath('data.direccion', 'Rada Tilly Av. Moyano');

        $this->assertDatabaseHas('reclamos', [
            'id' => $reclamo->id,
            'usuario_id' => $vecino->id,
            'estado_id' => $reclamo->estado_id,
            'titulo' => 'Luminaria caída en esquina',
        ]);
    }

    public function test_ciudadano_puede_agregar_y_quitar_fotos_al_editar_manteniendo_entre_una_y_cinco(): void
    {
        Storage::fake('public');
        $this->mockearApisExternas();

        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'pendiente');

        $foto1 = $reclamo->fotos()->first();
        $foto2 = $reclamo->fotos()->create(['ruta' => 'reclamos/segunda.jpg']);

        Sanctum::actingAs($vecino);

        // Usamos POST + _method=PUT igual que un formulario multipart desde la app móvil
        $response = $this->post("/api/reclamos/{$reclamo->id}", [
            '_method' => 'PUT',
            'descripcion' => 'Actualización con foto nueva',
            'fotos_eliminar' => [$foto1->id],
            'fotos' => [
                $this->crearImagenFalsa('nueva_calle.png'),
            ],
        ], ['Accept' => 'application/json']);

        $response->assertOk();
        $this->assertDatabaseMissing('fotos_reclamo', ['id' => $foto1->id]);
        $this->assertDatabaseHas('fotos_reclamo', ['id' => $foto2->id]);
        $this->assertEquals(2, $reclamo->fotos()->count());
    }

    public function test_no_permite_dejar_el_reclamo_sin_fotos_al_editar(): void
    {
        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'pendiente');
        $unicaFoto = $reclamo->fotos()->first();

        Sanctum::actingAs($vecino);

        $response = $this->putJson("/api/reclamos/{$reclamo->id}", [
            'fotos_eliminar' => [$unicaFoto->id],
        ]);

        $response->assertStatus(422)
            ->assertJsonFragment([
                'message' => 'El reclamo debe conservar al menos una foto.',
            ]);
    }

    public function test_rechaza_foto_nueva_con_personas_al_editar(): void
    {
        Storage::fake('public');
        $this->mockearApisExternas(faces: [['x1' => 0.1, 'y1' => 0.1]]);

        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'pendiente');

        Sanctum::actingAs($vecino);

        $response = $this->post("/api/reclamos/{$reclamo->id}", [
            '_method' => 'PUT',
            'foto' => $this->crearImagenFalsa('selfie.png'),
        ], ['Accept' => 'application/json']);

        $response->assertStatus(422)
            ->assertJsonFragment([
                'message' => 'La foto fue rechazada. No se permiten personas en la imagen, solo la infraestructura o el daño público.',
            ]);
    }

    public function test_no_puede_editar_reclamo_de_otro_usuario(): void
    {
        $dueno = $this->crearUsuario();
        $otroVecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($dueno, 'pendiente');

        Sanctum::actingAs($otroVecino);

        $this->putJson("/api/reclamos/{$reclamo->id}", [
            'titulo' => 'Intento de modificación ajena',
        ])->assertForbidden();
    }

    public function test_no_puede_editar_reclamo_que_ya_esta_en_proceso(): void
    {
        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'en_proceso');

        Sanctum::actingAs($vecino);

        $this->putJson("/api/reclamos/{$reclamo->id}", [
            'titulo' => 'Cambio tardío',
        ])->assertStatus(422);
    }

    public function test_usuario_suspendido_no_puede_editar_su_reclamo(): void
    {
        $vecino = $this->crearUsuario([
            'suspendido_hasta' => now()->addDays(15),
        ]);
        $reclamo = $this->crearReclamo($vecino, 'pendiente');

        Sanctum::actingAs($vecino);

        $this->putJson("/api/reclamos/{$reclamo->id}", [
            'titulo' => 'Editando estando suspendido',
        ])->assertForbidden();
    }

    public function test_ciudadano_puede_dar_de_baja_su_reclamo_pendiente_sin_cambios_de_estado(): void
    {
        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'pendiente');
        $foto = $reclamo->fotos()->first();

        Sanctum::actingAs($vecino);

        $this->deleteJson("/api/reclamos/{$reclamo->id}")
            ->assertOk()
            ->assertJsonFragment([
                'message' => 'Reclamo eliminado correctamente.',
            ]);

        // Verifica baja lógica y conservación de relaciones para auditoría administrativa
        $this->assertSoftDeleted('reclamos', ['id' => $reclamo->id]);
        $this->assertDatabaseHas('fotos_reclamo', ['id' => $foto->id]);
        $this->assertDatabaseHas('historial_estados_reclamos', ['reclamo_id' => $reclamo->id]);
    }

    public function test_no_puede_eliminar_reclamo_de_otro_usuario(): void
    {
        $dueno = $this->crearUsuario();
        $otroVecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($dueno, 'pendiente');

        Sanctum::actingAs($otroVecino);

        $this->deleteJson("/api/reclamos/{$reclamo->id}")
            ->assertForbidden();
    }

    public function test_no_puede_eliminar_reclamo_que_ya_cambio_de_estado(): void
    {
        $vecino = $this->crearUsuario();
        $reclamo = $this->crearReclamo($vecino, 'en_proceso');

        $estadoEnProceso = EstadoReclamo::where('nombre', 'en_proceso')->first();
        $reclamo->historialEstados()->create([
            'estado_id' => $estadoEnProceso->id,
            'usuario_id' => $vecino->id,
            'visibilidad' => 'publica',
            'created_at' => now(),
        ]);

        Sanctum::actingAs($vecino);

        $this->deleteJson("/api/reclamos/{$reclamo->id}")
            ->assertStatus(422);

        $this->assertNotSoftDeleted('reclamos', ['id' => $reclamo->id]);
    }

    private function crearUsuario(array $overrides = []): User
    {
        static $contador = 1;
        $numero = $contador++;

        return User::forceCreate(array_merge([
            'nombre' => "Vecino {$numero}",
            'apellido' => 'Test',
            'email' => "vecino{$numero}@example.com",
            'password' => bcrypt('password123'),
            'dni' => str_pad((string) (30000000 + $numero), 8, '0', STR_PAD_LEFT),
            'rol' => 'ciudadano',
            'activo' => true,
        ], $overrides));
    }

    private function crearReclamo(User $usuario, string $nombreEstado = 'pendiente', array $overrides = []): Reclamo
    {
        $estado = EstadoReclamo::firstOrCreate(['nombre' => $nombreEstado]);
        $tipo = TipoReclamo::firstOrCreate(
            ['nombre' => 'Alumbrado público'],
            ['descripcion' => 'Fallas de luminarias', 'activo' => true]
        );

        $reclamo = Reclamo::forceCreate(array_merge([
            'usuario_id' => $usuario->id,
            'tipo_reclamo_id' => $tipo->id,
            'estado_id' => $estado->id,
            'titulo' => 'Luminaria apagada',
            'descripcion' => 'Hace tres días que no prende el poste.',
            'latitud' => -45.8641300,
            'longitud' => -67.4965600,
            'direccion' => 'Centro San Martín',
            'es_publico' => true,
        ], $overrides));

        $reclamo->historialEstados()->create([
            'estado_id' => $estado->id,
            'usuario_id' => $usuario->id,
            'visibilidad' => 'publica',
            'created_at' => now(),
        ]);

        $reclamo->fotos()->create([
            'ruta' => 'reclamos/foto_inicial.jpg',
        ]);

        return $reclamo;
    }

    private function mockearApisExternas(array $faces = []): void
    {
        Http::fake([
            'api.sightengine.com/*' => Http::response([
                'status' => 'success',
                'nudity' => [
                    'raw' => 0.01,
                    'erotica' => 0.01,
                    'sexual_activity' => 0.01,
                    'suggestive' => 0.01,
                    'suggestive_classes' => [
                        'bikini' => 0.01,
                        'male_chest' => 0.01,
                        'lingerie' => 0.01,
                        'male_underwear' => 0.01,
                    ],
                ],
                'gore' => ['prob' => 0.01],
                'faces' => $faces,
            ], 200),
            'nominatim.openstreetmap.org/*' => Http::response([
                'address' => [
                    'suburb' => 'Rada Tilly',
                    'road' => 'Av. Moyano',
                ],
            ], 200),
        ]);
    }
    private function crearImagenFalsa(string $nombre = 'foto.png'): UploadedFile
    {
        // PNG válido de 1x1 píxel (pasa la validación 'image' de Laravel sin necesitar extensión GD)
        $pngValido = base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
        );

        return UploadedFile::fake()->createWithContent($nombre, $pngValido);
    }
}