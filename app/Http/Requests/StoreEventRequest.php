<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreEventRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string', 'max:5000'],
            'location' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'in:marathon,hyrox,charity_run,community,other'],
            'image' => ['nullable', 'image', 'max:2048'],
            'registration_deadline' => ['required', 'date', 'after:today'],
            'starts_at' => ['required', 'date', 'after:registration_deadline'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'capacity' => ['nullable', 'integer', 'min:1'],
            'fee' => ['nullable', 'numeric', 'min:0'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'starts_at.after' => 'The event must start after the registration deadline.',
            'ends_at.after' => 'The event must end after it starts.',
            'registration_deadline.after' => 'The registration deadline must be in the future.',
        ];
    }
}
